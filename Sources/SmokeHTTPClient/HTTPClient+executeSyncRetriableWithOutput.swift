// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPClient+executeSyncRetriableWithOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import Logging
import Metrics

public extension HTTPClient {
    /**
     Helper type that manages the state of a retriable sync request.
     */
    private class ExecuteSyncWithOutputRetriable<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>
            where InputType: HTTPRequestInputProtocol,
            OutputType: HTTPResponseOutputProtocol {
        let endpointOverride: URL?
        let endpointPath: String
        let httpMethod: HTTPMethod
        let input: InputType
        let invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>
        let innerInvocationContext:
            HTTPClientInvocationContext<HTTPClientInnerRetryInvocationReporting<InvocationReportingType.TraceContextType>, HandlerDelegateType>
        let httpClient: HTTPClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (HTTPClientError) -> Bool
        let latencyMetricDetails: (Date, Metrics.Timer)?
        
        var retriesRemaining: Int
        
        let milliToMicroSeconds = 1000
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod,
             input: InputType,
             invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
             httpClient: HTTPClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (Swift.Error) -> Bool) {
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
        
        func executeSyncWithOutput() throws -> OutputType {
            defer {
                // report the retryCount metric
                let retryCount = retryConfiguration.numRetries - retriesRemaining
                invocationContext.reporting.retryCountRecorder?.record(retryCount)
                
                if let durationMetricDetails = latencyMetricDetails {
                    durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
                }
            }
            
            do {
                // submit the synchronous request
                let value: OutputType = try httpClient.executeSyncWithOutput(endpointOverride: endpointOverride,
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
                
                logger.debug("Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). Retrying in \(retryInterval) ms.")
                usleep(useconds_t(retryInterval * milliToMicroSeconds))
                logger.debug("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                return try executeSyncWithOutput()
            } else {
                if !shouldRetryOnError {
                    logger.debug("Request not retried due to error returned: \(error)")
                } else {
                    logger.debug("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
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
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (Swift.Error) -> Bool) throws -> OutputType
        where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {

            let retriable = ExecuteSyncWithOutputRetriable<InputType, OutputType, InvocationReportingType, HandlerDelegateType>(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input,
                invocationContext: invocationContext, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            return try retriable.executeSyncWithOutput()
    }
}
