// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPOperationsClient+executeRetriableWithoutOutput.swift
//  SmokeHTTPClient
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import Foundation
import AsyncHTTPClient
import NIO
import NIOHTTP1
import NIOHTTP2
import Metrics
import Tracing

private let millisecondsToNanoSeconds: UInt64 = 1000000

public extension HTTPOperationsClient {
    /**
     Helper type that manages the state of a retriable async request.
     */
    private class ExecuteWithoutOutputRetriable<InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate> {
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
        
        // For requests that fail for transient connection issues (StreamClosed, remoteConnectionClosed)
        // don't consume retry attempts and don't use expotential backoff
        var abortedAttemptsRemaining: Int = 5
        let waitOnAbortedAttemptMs = 2
        
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
        
        func executeWithoutOutput() async throws {
            // submit the asynchronous request
            do {
                try await httpClient.executeWithoutOutputWithWrappedInvocationContext(
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
                
                try await self.retry(error: httpClientError)
                return
            }
            
            await self.onSuccess()
        }
        
        func onSuccess() async{
            // report success metric
            invocationContext.reporting.successCounter?.increment()
            
            return await onComplete()
        }
        
        func retry(error: HTTPClientError) async throws {
            let logger = invocationContext.reporting.logger

            let shouldRetryOnError = retryOnError(error)
            
            // For requests that fail for transient connection issues (StreamClosed, remoteConnectionClosed)
            // don't consume retry attempts and don't use expotential backoff
            if self.abortedAttemptsRemaining > 0 && treatAsAbortedAttempt(cause: error.cause) {
                logger.debug(
                    "Request aborted with error: \(error). Retrying in \(self.waitOnAbortedAttemptMs) ms.")
                
                self.abortedAttemptsRemaining -= 1
                
                try await Task.sleep(nanoseconds: UInt64(self.waitOnAbortedAttemptMs) * millisecondsToNanoSeconds)
                
                try await self.executeWithoutOutput()
                
                return
                // if there are retries remaining (and haven't exhausted aborted attempts) and we should retry on this error
            } else if self.abortedAttemptsRemaining > 0 && self.retriesRemaining > 0 && shouldRetryOnError {
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
                
                try await self.executeWithoutOutput()
                
                return
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
        
        func treatAsAbortedAttempt(cause: Swift.Error) -> Bool {
            if cause is NIOHTTP2Errors.StreamClosed {
                return true
            } else if let clientError = cause as? AsyncHTTPClient.HTTPClientError, clientError == .remoteConnectionClosed {
                return true
            }
            
            return false
        }
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - clientName: Optionally the name of the client to use for reporting.
        - operation: Optionally the name of the operation to use for reporting.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     - Throws: If an error occurred during the request.
     */
    func executeRetriableWithoutOutput<InputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        clientName: String? = nil,
        operation: String? = nil,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (HTTPClientError) -> Bool) async throws
    where InputType: HTTPRequestInputProtocol {
        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath,
            invocationReporting: invocationContext.reporting)
        let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
        let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
    
        // use the specified event loop or pick one for the client to use for all retry attempts
        let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()
        
        let retriable = ExecuteWithoutOutputRetriable<StandardHTTPClientInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>(
            endpointOverride: endpointOverride, requestComponents: requestComponents,
            httpMethod: httpMethod,
            invocationContext: wrappingInvocationContext, eventLoopOverride: eventLoop, httpClient: self,
            retryConfiguration: retryConfiguration,
            retryOnError: retryOnError)
        
        let clientNameToUse = clientName ?? "UnnamedClient"
        let operationToUse = operation ?? "UnnamedOperation"
        let spanName = "\(clientNameToUse).\(operationToUse)"

        return try await withSpanIfEnabled(spanName) { _ in
            return try await retriable.executeWithoutOutput()
        }
    }
}

#endif
