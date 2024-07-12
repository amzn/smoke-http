// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPOperationsClient+executeAsEventLoopFutureRetriableWithOutput.swift
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
    private class ExecuteAsEventLoopFutureWithOutputRetriable<OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>
            where OutputType: HTTPResponseOutputProtocol {
        let endpointOverride: URL?
        let requestComponents: HTTPRequestComponents
        let httpMethod: HTTPMethod
        let invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>
        let eventLoop: EventLoop
        let innerInvocationContext:
            HTTPClientInvocationContext<HTTPClientInnerRetryInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>
        let httpClient: HTTPOperationsClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (HTTPClientError) -> Bool
        let queue = DispatchQueue.global()
        let latencyMetricDetails: (Date, Metrics.Timer)?
        let outwardsRequestAggregators: (OutwardsRequestAggregator, RetriableOutwardsRequestAggregator)?
        
        var retriesRemaining: Int
        
        init(endpointOverride: URL?, requestComponents: HTTPRequestComponents, httpMethod: HTTPMethod,
             invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
             eventLoopOverride eventLoop: EventLoop,
             httpClient: HTTPOperationsClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (HTTPClientError) -> Bool) {
            self.endpointOverride = endpointOverride
            self.requestComponents = requestComponents
            self.httpMethod = httpMethod
            self.invocationContext = invocationContext
            self.eventLoop = eventLoop
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
        
        func executeAsEventLoopFutureWithOutput() -> EventLoopFuture<OutputType> {
            // submit the asynchronous request
            let future: EventLoopFuture<OutputType> = httpClient.executeAsEventLoopFutureWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents, httpMethod: httpMethod,
                invocationContext: innerInvocationContext).flatMapError { error -> EventLoopFuture<OutputType> in
                let httpClientError: HTTPClientError
                if let typedError = error as? HTTPClientError {
                    httpClientError = typedError
                } else {
                    // if a non-HTTPClientError is thrown, wrap it
                    httpClientError = HTTPClientError(responseCode: 400, cause: error)
                }
                
                return self.getNextFuture(error: httpClientError)
            }
            
            return future.flatMap { result in
                return self.onSuccess().map { result }
            }
        }
        
        func onSuccess() -> EventLoopFuture<Void> {
            // report success metric
            invocationContext.reporting.successCounter?.increment()
            
            return onComplete()
        }
        
        func getNextFuture(error: HTTPClientError) -> EventLoopFuture<OutputType> {
            let promise = self.eventLoop.makePromise(of: OutputType.self)
            let logger = invocationContext.reporting.logger

            let shouldRetryOnError = retryOnError(error)
            
            // if there are retries remaining and we should retry on this error
            if retriesRemaining > 0 && shouldRetryOnError {
                // determine the required interval
                let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                
                let currentRetriesRemaining = retriesRemaining
                retriesRemaining -= 1
                
                let recordFuture: EventLoopFuture<Void>
                if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                    let promise = self.eventLoop.makePromise(of: Void.self)
                    outwardsRequestAggregators.0.recordRetryAttempt(
                        retryAttemptRecord: StandardRetryAttemptRecord(retryWait: retryInterval.millisecondsToTimeInterval)) {
                            promise.succeed(())
                        }
                    
                    recordFuture = promise.futureResult
                } else {
                    recordFuture = self.eventLoop.makeSucceededVoidFuture()
                }
                
                logger.warning(
                    "Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms.")
                let deadline = DispatchTime.now() + .milliseconds(retryInterval)
                queue.asyncAfter(deadline: deadline) {
                    logger.trace("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                    
                    let nextFuture = self.executeAsEventLoopFutureWithOutput()
                    
                    promise.completeWith(nextFuture)
                }
                
                // return the future that will be completed with the future retry.
                return recordFuture.flatMap { promise.futureResult }
            }
            
            if !shouldRetryOnError {
                logger.trace("Request not retried due to error returned: \(error)")
            } else {
                logger.trace("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
            }
            
            // its an error; complete with the provided error
            promise.fail(error)
            
            // report failure metric
            switch error.category {
            case .clientError, .clientRetryableError:
                invocationContext.reporting.failure4XXCounter?.increment()
            case .serverError:
                invocationContext.reporting.failure5XXCounter?.increment()
            }
            
            let reportFuture = onComplete()

            return reportFuture.flatMap { promise.futureResult }
        }
        
        func onComplete() -> EventLoopFuture<Void> {
            // report the retryCount metric
            let retryCount = retryConfiguration.numRetries - retriesRemaining
            invocationContext.reporting.retryCountRecorder?.record(retryCount)
            
            if let durationMetricDetails = latencyMetricDetails {
                durationMetricDetails.1.recordMilliseconds(Date().timeIntervalSince(durationMetricDetails.0).milliseconds)
            }
            
            // submit all the request latencies captured by the RetriableOutwardsRequestAggregator
            // to the provided outwardsRequestAggregator if it was provided
            if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                let promise = self.eventLoop.makePromise(of: Void.self)
                
                outwardsRequestAggregators.1.withRecords { outputRequestRecords in
                    outwardsRequestAggregators.0.recordRetriableOutwardsRequest(
                        retriableOutwardsRequest: StandardRetriableOutputRequestRecord(outputRequests: outputRequestRecords)) {
                            promise.succeed(())
                        }
                }
                
                
                return promise.futureResult
            }
            
            return self.eventLoop.makeSucceededVoidFuture()
        }
    }
    
    /**
     Submits a request that will return a response body to this client asynchronously as an EventLoopFuture.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     - Returns: A future that will produce the execution result or failure.
     */
    func executeAsEventLoopFutureRetriableWithOutput<InputType, OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String? = nil,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            retryConfiguration: HTTPClientRetryConfiguration,
            retryOnError: @escaping (HTTPClientError) -> Bool) -> EventLoopFuture<OutputType>
    where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
        // use the specified event loop or pick one for the client to use for all retry attempts
        let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()
        let requestComponents: HTTPRequestComponents
        do {
            requestComponents = try clientDelegate.encodeInputAndQueryString(
                input: input,
                httpPath: endpointPath,
                invocationReporting: invocationContext.reporting)
        } catch {
            return eventLoop.makeFailedFuture(error)
        }

        let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
        let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
        
        let retriable = ExecuteAsEventLoopFutureWithOutputRetriable<OutputType, StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
            endpointOverride: endpointOverride, requestComponents: requestComponents,
            httpMethod: httpMethod,
            invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
            retryConfiguration: retryConfiguration,
            retryOnError: retryOnError)
        
        return retriable.executeAsEventLoopFutureWithOutput()
    }
}
