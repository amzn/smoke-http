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
//  HTTPOperationsClient+executeRetriableWithOutput.swift
//  SmokeHTTPClient
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import Foundation
import NIO
import NIOHTTP1
import Metrics

private let millisecondsToNanoSeconds: UInt64 = 1000000

// Copy of extension from SwiftNIO; can be removed when the version in SwiftNIO removes its @available attribute
internal extension EventLoopFuture {
    /// Get the value/error from an `EventLoopFuture` in an `async` context.
    ///
    /// This function can be used to bridge an `EventLoopFuture` into the `async` world. Ie. if you're in an `async`
    /// function and want to get the result of this future.
    @inlinable
    func get() async throws -> Value {
        return try await withCheckedThrowingContinuation { cont in
            self.whenComplete { result in
                switch result {
                case .success(let value):
                    cont.resume(returning: value)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

public extension HTTPOperationsClient {
    /**
     Helper type that manages the state of a retriable async request.
     */
    private class ExecuteWithOutputRetriable<OutputType,
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
                                                                         eventLoop: nil,
                                                                         outwardsRequestAggregator: outwardsRequestAggregators?.1)
            self.innerInvocationContext = HTTPClientInvocationContext(reporting: innerReporting, handlerDelegate: invocationContext.handlerDelegate)
        }
        
        func executeWithOutput() async throws -> OutputType {
            // submit the asynchronous request
            let result: OutputType
            do {
                result = try await httpClient.executeWithOutputWithWrappedInvocationContext(
                    endpointOverride: endpointOverride,
                    requestComponents: requestComponents, httpMethod: httpMethod,
                    invocationContext: innerInvocationContext)
            } catch {
                let httpClientError: HTTPClientError
                if let typedError = error as? HTTPClientError {
                    httpClientError = typedError
                } else {
                    // if a non-HTTPClientError is thrown, wrap it
                    httpClientError = HTTPClientError(responseCode: 400, cause: error)
                }
                
                return try await self.retry(error: httpClientError)
            }
            
            await self.onSuccess()
            
            return result
        }
        
        func onSuccess() async {
            // report success metric
            invocationContext.reporting.successCounter?.increment()
            
            await onComplete()
        }
        
        func retry(error: HTTPClientError) async throws -> OutputType {
            let logger = invocationContext.reporting.logger

            let shouldRetryOnError = retryOnError(error)
            
            // if there are retries remaining and we should retry on this error
            if retriesRemaining > 0 && shouldRetryOnError {
                // determine the required interval
                let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                
                let currentRetriesRemaining = retriesRemaining
                retriesRemaining -= 1
                
                if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                    await outwardsRequestAggregators.0.recordRetryAttempt(
                        retryAttemptRecord: StandardRetryAttemptRecord(retryWait: retryInterval.millisecondsToTimeInterval))
                }
                
                logger.warning(
                    "Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms.")
                try await Task.sleep(nanoseconds: UInt64(retryInterval) * millisecondsToNanoSeconds)
                logger.trace("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                
                return try await self.executeWithOutput()
            }
            
            if !shouldRetryOnError {
                logger.trace("Request not retried due to error returned: \(error)")
            } else {
                logger.trace("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
            }
            
            // report failure metric
            switch error.category {
            case .clientError:
                invocationContext.reporting.failure4XXCounter?.increment()
            case .serverError:
                invocationContext.reporting.failure5XXCounter?.increment()
            }
            
            await onComplete()

            // its an error; complete with the provided error
            throw error
        }
        
        func onComplete() async {
            // report the retryCount metric
            let retryCount = retryConfiguration.numRetries - retriesRemaining
            invocationContext.reporting.retryCountRecorder?.record(retryCount)
            
            if let durationMetricDetails = latencyMetricDetails {
                durationMetricDetails.1.recordMilliseconds(Date().timeIntervalSince(durationMetricDetails.0).milliseconds)
            }
            
            // submit all the request latencies captured by the RetriableOutwardsRequestAggregator
            // to the provided outwardsRequestAggregator if it was provided
            if let outwardsRequestAggregators = self.outwardsRequestAggregators {
                let outputRequestRecords = await outwardsRequestAggregators.1.records()
                
                await outwardsRequestAggregators.0.recordRetriableOutwardsRequest(
                    retriableOutwardsRequest: StandardRetriableOutputRequestRecord(outputRequests: outputRequestRecords))
            }
        }
    }
    
    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     - Returns: the response body.
     - Throws: If an error occurred during the request.
     */
    func executeRetriableWithOutput<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (HTTPClientError) -> Bool) async throws -> OutputType
    where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath,
            invocationReporting: invocationContext.reporting)
        let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
        let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
    
        // use the specified event loop or pick one for the client to use for all retry attempts
        let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()
        
        let retriable = ExecuteWithOutputRetriable<OutputType, StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
            endpointOverride: endpointOverride, requestComponents: requestComponents,
            httpMethod: httpMethod,
            invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
            retryConfiguration: retryConfiguration,
            retryOnError: retryOnError)
        
        return try await retriable.executeWithOutput()
    }
}

#endif
