// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//  HTTPOperationsClient+executeAsyncRetriableWithoutOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import Logging
import Metrics

public extension HTTPOperationsClient {
    /**
     Helper type that manages the state of a retriable async request.
     */
    private class ExecuteAsyncWithoutOutputRetriable<InputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
            InvocationStrategyType.OutputType == HTTPClientError? {
        let endpointOverride: URL?
        let endpointPath: String
        let httpMethod: HTTPMethod
        let input: InputType
        let outerCompletion: (HTTPClientError?) -> ()
        let asyncResponseInvocationStrategy: InvocationStrategyType
        let invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>
        let innerInvocationContext:
            HTTPClientInvocationContext<HTTPClientInnerRetryInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>
        let httpClient: HTTPOperationsClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (HTTPClientError) -> Bool
        let queue = DispatchQueue.global()
        let latencyMetricDetails: (Date, Metrics.Timer)?
        let outwardsRequestAggregators: (OutwardsRequestAggregator, RetriableOutwardsRequestAggregator)?
        
        var retriesRemaining: Int
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod,
             input: InputType, outerCompletion: @escaping (HTTPClientError?) -> (),
             asyncResponseInvocationStrategy: InvocationStrategyType,
             invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
             eventLoopOverride eventLoop: EventLoop,
             httpClient: HTTPOperationsClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (HTTPClientError) -> Bool) {
            self.endpointOverride = endpointOverride
            self.endpointPath = endpointPath
            self.httpMethod = httpMethod
            self.input = input
            self.outerCompletion = outerCompletion
            self.asyncResponseInvocationStrategy = asyncResponseInvocationStrategy
            self.invocationContext = invocationContext
            self.httpClient = httpClient
            self.retryConfiguration = retryConfiguration
            self.retryOnError = retryOnError
            self.retriesRemaining = retryConfiguration.numRetries
            
            // if the request latencies need to be aggregated
            if let outwardsRequestAggregator = invocationContext.reporting.outwardsRequestAggregator {
                outwardsRequestAggregators = (outwardsRequestAggregator, RetriableOutwardsRequestAggregator())
            } else {
                outwardsRequestAggregators = nil
            }
            
            if let latencyTimer = invocationContext.reporting.latencyTimer {
                self.latencyMetricDetails = (Date(), latencyTimer)
            } else {
                self.latencyMetricDetails = nil
            }
            // When using retry wrappers, the `HTTPClient` itself shouldn't record any metrics.
            let innerReporting = HTTPClientInnerRetryInvocationReporting(internalRequestId: invocationContext.reporting.internalRequestId,
                                                                         traceContext: invocationContext.reporting.traceContext,
                                                                         logger: invocationContext.reporting.logger,
                                                                         eventLoop: eventLoop,
                                                                         outwardsRequestAggregator: outwardsRequestAggregators?.1)
            self.innerInvocationContext = HTTPClientInvocationContext(reporting: innerReporting, handlerDelegate: invocationContext.handlerDelegate)
        }
        
        func executeAsyncWithoutOutput() throws {
            // submit the asynchronous request
            _ = try httpClient.executeAsyncWithoutOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath, httpMethod: httpMethod,
                input: input, completion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: innerInvocationContext)
        }
        
        func completion(innerError: HTTPClientError?) {
            let error: HTTPClientError?
            let logger = invocationContext.reporting.logger

            if let innerError = innerError {
                let shouldRetryOnError = retryOnError(innerError)
                
                // if there are retries remaining and we should retry on this error
                if retriesRemaining > 0 && shouldRetryOnError {
                    // determine the required interval
                    let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                    
                    let currentRetriesRemaining = retriesRemaining
                    retriesRemaining -= 1
                    
                    func afterRecordCompletion() {
                        let retryDescription = "Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms."
                        logger.warning("Request failed with error: \(innerError). \(retryDescription)")
                        let deadline = DispatchTime.now() + .milliseconds(retryInterval)
                        queue.asyncAfter(deadline: deadline) {
                            logger.trace("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                            do {
                                // execute again
                                try self.executeAsyncWithoutOutput()
                                return
                            } catch {
                                // its attempting to retry causes an error; complete with the provided error
                                self.outerCompletion(innerError)
                            }
                        }
                    }
                    
                    if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                        outwardsRequestAggregators.0.recordRetryAttempt(
                            retryAttemptRecord: StandardRetryAttemptRecord(retryWait: retryInterval.millisecondsToTimeInterval),
                            onCompletion: afterRecordCompletion)
                    } else {
                        afterRecordCompletion()
                    }
                    
                    // request will be retried; don't complete yet
                    return
                }
                
                if !shouldRetryOnError {
                    logger.trace("Request not retried due to error returned: \(innerError)")
                } else {
                    logger.trace("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
                }
                
                // its an error; complete with the provided error
                error = innerError
                
                // report failure metric
                switch innerError.category {
                case .clientError:
                    invocationContext.reporting.failure4XXCounter?.increment()
                case .serverError:
                    invocationContext.reporting.failure5XXCounter?.increment()
                }
            } else {
                error = innerError
                
                // report success metric
                invocationContext.reporting.successCounter?.increment()
            }
            
            // report the retryCount metric
            let retryCount = retryConfiguration.numRetries - retriesRemaining
            invocationContext.reporting.retryCountRecorder?.record(retryCount)
            
            if let durationMetricDetails = latencyMetricDetails {
                durationMetricDetails.1.recordMilliseconds(Date().timeIntervalSince(durationMetricDetails.0).milliseconds)
            }
            
            func afterRecordCompletion() {
                outerCompletion(error)
            }
            
            // submit all the request latencies captured by the RetriableOutwardsRequestAggregator
            // to the provided outwardsRequestAggregator if it was provided
            if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                outwardsRequestAggregators.1.withRecords { outputRequestRecords in
                    outwardsRequestAggregators.0.recordRetriableOutwardsRequest(
                        retriableOutwardsRequest: StandardRetriableOutputRequestRecord(outputRequests: outputRequestRecords),
                        onCompletion: afterRecordCompletion)
                }
            } else {
                afterRecordCompletion()
            }
        }
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with an error if one occurs or nil otherwise.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeAsyncRetriableWithoutOutput<InputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (HTTPClientError?) -> (),
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (HTTPClientError) -> Bool) throws
        where InputType: HTTPRequestInputProtocol {
            try executeAsyncRetriableWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<HTTPClientError?>(),
                invocationContext: invocationContext,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
    }
    
    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with the response body or any error.
        - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeAsyncRetriableWithoutOutput<InputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (HTTPClientError?) -> (),
        asyncResponseInvocationStrategy: InvocationStrategyType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (HTTPClientError) -> Bool) throws
        where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == HTTPClientError? {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
        
            // use the specified event loop or pick one for the client to use for all retry attempts
            let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()

            let retriable = ExecuteAsyncWithoutOutputRetriable(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input, outerCompletion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            try retriable.executeAsyncWithoutOutput()
    }
}
