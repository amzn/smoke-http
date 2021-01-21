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
//  HTTPOperationsClient+executeAsEventLoopFutureRetriableWithoutOutput.swift
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
    private class ExecuteAsEventLoopFutureWithoutOutputRetriable<InputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>
            where InputType: HTTPRequestInputProtocol {
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
        let queue = DispatchQueue.global()
        let latencyMetricDetails: (Date, Metrics.Timer)?
        
        var retriesRemaining: Int
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod, input: InputType,
             invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
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
            
            if let latencyTimer = invocationContext.reporting.latencyTimer {
                self.latencyMetricDetails = (Date(), latencyTimer)
            } else {
                self.latencyMetricDetails = nil
            }
            // When using retry wrappers, the `HTTPClient` itself shouldn't record any metrics.
            let innerReporting = HTTPClientInnerRetryInvocationReporting(internalRequestId: invocationContext.reporting.internalRequestId,
                                                                         traceContext: invocationContext.reporting.traceContext,
                                                                         logger: invocationContext.reporting.logger)
            self.innerInvocationContext = HTTPClientInvocationContext(reporting: innerReporting, handlerDelegate: invocationContext.handlerDelegate)
        }
        
        func executeAsEventLoopFutureWithoutOutput(eventLoopOverride: EventLoop?) -> EventLoopFuture<Void> {
            // use the specified event loop or pick one for the client to use for all retry attempts
            let eventLoop = eventLoopOverride ?? self.httpClient.eventLoopGroup.next()
            
            // submit the asynchronous request
            let future: EventLoopFuture<Void> = httpClient.executeAsEventLoopFutureWithoutOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                eventLoopOverride: eventLoop,
                endpointPath: endpointPath, httpMethod: httpMethod,
                input: input, invocationContext: innerInvocationContext).flatMapError { error -> EventLoopFuture<Void> in
                let httpClientError: HTTPClientError
                if let typedError = error as? HTTPClientError {
                    httpClientError = typedError
                } else {
                    // if a non-HTTPClientError is thrown, wrap it
                    httpClientError = HTTPClientError(responseCode: 400, cause: error)
                }
                
                return self.getNextFuture(error: httpClientError, eventLoop: eventLoop)
            }
            
            future.whenSuccess { _ in
                self.onSuccess()
            }
            
            return future
        }
        
        func onSuccess() {
            // report success metric
            invocationContext.reporting.successCounter?.increment()
            
            onComplete()
        }
        
        func getNextFuture(error: HTTPClientError, eventLoop: EventLoop) -> EventLoopFuture<Void> {
            let promise = eventLoop.makePromise(of: Void.self)
            let logger = invocationContext.reporting.logger

            let shouldRetryOnError = retryOnError(error)
            
            // if there are retries remaining and we should retry on this error
            if retriesRemaining > 0 && shouldRetryOnError {
                // determine the required interval
                let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                
                let currentRetriesRemaining = retriesRemaining
                retriesRemaining -= 1
                
                logger.warning(
                    "Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms.")
                let deadline = DispatchTime.now() + .milliseconds(retryInterval)
                queue.asyncAfter(deadline: deadline) {
                    logger.debug("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                    
                    let nextFuture = self.executeAsEventLoopFutureWithoutOutput(eventLoopOverride: eventLoop)
                    
                    promise.completeWith(nextFuture)
                }
                
                // return the future that will be completed with the future retry.
                return promise.futureResult
            }
            
            if !shouldRetryOnError {
                logger.debug("Request not retried due to error returned: \(error)")
            } else {
                logger.debug("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
            }
            
            // its an error; complete with the provided error
            promise.fail(error)
            
            // report failure metric
            switch error.category {
            case .clientError:
                invocationContext.reporting.failure4XXCounter?.increment()
            case .serverError:
                invocationContext.reporting.failure5XXCounter?.increment()
            }
            
            onComplete()

            return promise.futureResult
        }
        
        func onComplete() {
            // report the retryCount metric
            let retryCount = retryConfiguration.numRetries - retriesRemaining
            invocationContext.reporting.retryCountRecorder?.record(retryCount)
            
            if let durationMetricDetails = latencyMetricDetails {
                durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
            }
        }
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously as an EventLoopFuture.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     - Returns: A future that will produce a Void result or failure.
     */
    func executeAsEventLoopFutureRetriableWithoutOutput<InputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            eventLoopOverride: EventLoop? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            retryConfiguration: HTTPClientRetryConfiguration,
            retryOnError: @escaping (HTTPClientError) -> Bool) -> EventLoopFuture<Void>
        where InputType: HTTPRequestInputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
            
            let retriable = ExecuteAsEventLoopFutureWithoutOutputRetriable<InputType, StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input,
                invocationContext: wrappingInvocationContext, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            return retriable.executeAsEventLoopFutureWithoutOutput(eventLoopOverride: eventLoopOverride)
    }
}
