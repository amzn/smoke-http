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
//  HTTPOperationsClient+executeSyncRetriableWithOutput.swift
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
     Helper type that manages the state of a retriable sync request.
     */
    private class ExecuteSyncWithOutputRetriable<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>
            where InputType: HTTPRequestInputProtocol,
            OutputType: HTTPResponseOutputProtocol {
        let endpointOverride: URL?
        let endpointPath: String
        let httpMethod: HTTPMethod
        let input: InputType
        let invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>
        let innerInvocationContext:
            HTTPClientInvocationContext<HTTPClientInnerRetryInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>
        let httpClient: HTTPOperationsClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (HTTPClientError) -> Bool
        let latencyMetricDetails: (Date, Metrics.Timer)?
        let outwardsRequestAggregators: (OutwardsRequestAggregator, RetriableOutwardsRequestAggregator)?
        
        var retriesRemaining: Int
        
        let milliToMicroSeconds = 1000
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod,
             input: InputType,
             invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
             eventLoopOverride eventLoop: EventLoop,
             httpClient: HTTPOperationsClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (HTTPClientError) -> Bool) {
            self.endpointOverride = endpointOverride
            self.endpointPath = endpointPath
            self.httpMethod = httpMethod
            self.input = input
            self.invocationContext = invocationContext
            self.httpClient = httpClient
            self.retryConfiguration = retryConfiguration
            self.retriesRemaining = retryConfiguration.numRetries
            self.retryOnError = retryOnError
            
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
        
        func executeSyncWithOutput() throws -> OutputType {
            defer {
                // report the retryCount metric
                let retryCount = retryConfiguration.numRetries - retriesRemaining
                invocationContext.reporting.retryCountRecorder?.record(retryCount)
                
                if let durationMetricDetails = latencyMetricDetails {
                    durationMetricDetails.1.recordMilliseconds(Date().timeIntervalSince(durationMetricDetails.0).milliseconds)
                }
                
                // submit all the request latencies captured by the RetriableOutwardsRequestAggregator
                // to the provided outwardsRequestAggregator if it was provided
                if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                    outwardsRequestAggregators.0.recordRetriableOutwardsRequest(
                        retriableOutwardsRequest: StandardRetriableOutputRequestRecord(outputRequests: outwardsRequestAggregators.1.outputRequestRecords))
                }
            }
            
            do {
                // submit the synchronous request
                let value: OutputType = try httpClient.executeSyncWithOutputWithWrappedInvocationContext(
                    endpointOverride: endpointOverride,
                    endpointPath: endpointPath, httpMethod: httpMethod,
                    input: input, invocationContext: innerInvocationContext)
                
                // report success metric
                invocationContext.reporting.successCounter?.increment()
                
                return value
            } catch let error as HTTPClientError {
                // report failure metric
                switch error.category {
                case .clientError:
                    invocationContext.reporting.failure4XXCounter?.increment()
                case .serverError:
                    invocationContext.reporting.failure5XXCounter?.increment()
                }
                
                return try completeOnError(error: error)
            } catch {
                // report success metric
                invocationContext.reporting.failure4XXCounter?.increment()
                
                return try completeOnError(error: HTTPClientError(responseCode: 400, cause: error))
            }
        }
        
        func completeOnError(error: HTTPClientError) throws -> OutputType {
            let shouldRetryOnError: Bool
            switch error.category {
            case .clientError:
                // never retry
                shouldRetryOnError = false
            case .serverError:
                shouldRetryOnError = retryOnError(error)
            }
            let logger = invocationContext.reporting.logger
            
            // if there are retries remaining and we should retry on this error
            if retriesRemaining > 0 && shouldRetryOnError {
                // determine the required interval
                let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                
                let currentRetriesRemaining = retriesRemaining
                retriesRemaining -= 1
                
                if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                    outwardsRequestAggregators.0.recordRetryAttempt(
                        retryAttemptRecord: StandardRetryAttemptRecord(retryWait: retryInterval.millisecondsToTimeInterval))
                }
                
                logger.trace("Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms.")
                usleep(useconds_t(retryInterval * milliToMicroSeconds))
                logger.trace("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                return try executeSyncWithOutput()
            } else {
                if !shouldRetryOnError {
                    logger.trace("Request not retried due to error returned: \(error)")
                } else {
                    logger.trace("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
                }
                
                throw error
            }
        }
    }
    
    /**
     Submits a request that will return a response body to this client synchronously.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeSyncRetriableWithOutput<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (HTTPClientError) -> Bool) throws -> OutputType
        where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
        
            // use the specified event loop or pick one for the client to use for all retry attempts
            let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()

            let retriable = ExecuteSyncWithOutputRetriable<InputType, OutputType,
                    StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input,
                invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            return try retriable.executeSyncWithOutput()
    }
    
    @available(swift, deprecated: 3.0, message: "Provide a `retryOnError` handler that accepts a HTTPClientError instance.")
    func executeSyncRetriableWithOutput<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (Swift.Error) -> Bool) throws -> OutputType
        where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
        
            // use the specified event loop or pick one for the client to use for all retry attempts
            let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()

            let retriable = ExecuteSyncWithOutputRetriable<InputType, OutputType,
                    StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input,
                invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            return try retriable.executeSyncWithOutput()
    }
}
