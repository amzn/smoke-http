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
//  HTTPOperationsClient+executeAsyncWithoutOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient
import NIOSSL
import NIOTLS
import Logging
import Metrics

public extension HTTPOperationsClient {
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
     */
    func executeAsyncWithoutOutput<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (HTTPClientError?) -> (),
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
        where InputType: HTTPRequestInputProtocol {
            return try executeAsyncWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<HTTPClientError?>(),
                invocationContext: invocationContext)
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with an error if one occurs or nil otherwise.
        - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
        - invocationContext: context to use for this invocation.
     */
    func executeAsyncWithoutOutput<InputType, InvocationStrategyType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (HTTPClientError?) -> (),
        asyncResponseInvocationStrategy: InvocationStrategyType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
        where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == HTTPClientError? {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
            
            return try executeAsyncWithoutOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: wrappingInvocationContext)
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously. To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with an error if one occurs or nil otherwise.
        - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
        - invocationContext: context to use for this invocation.
     */
    internal func executeAsyncWithoutOutputWithWrappedInvocationContext<InputType, InvocationStrategyType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (HTTPClientError?) -> (),
        asyncResponseInvocationStrategy: InvocationStrategyType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
        where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == HTTPClientError? {
            
            let latencyMetricDetails: (Date, Metrics.Timer)?
            if let latencyTimer = invocationContext.reporting.latencyTimer {
                latencyMetricDetails = (Date(), latencyTimer)
            } else {
                latencyMetricDetails = nil
            }
            
            // create a wrapping completion handler to pass to the ChannelInboundHandler
            let wrappingCompletion: (Result<HTTPResponseComponents, HTTPClientError>) -> () = { (rawResult) in
                let result: HTTPClientError?
                
                switch rawResult {
                case .failure(let error):
                    // its an error, complete with this error
                    result = error
                    
                    // report failure metric
                    switch error.category {
                    case .clientError:
                        invocationContext.reporting.failure4XXCounter?.increment()
                    case .serverError:
                        invocationContext.reporting.failure5XXCounter?.increment()
                    }
                case .success:
                    // its a successful completion, complete with an empty error.
                    result = nil
                    
                    // report success metric
                    invocationContext.reporting.successCounter?.increment()
                }
                
                if let durationMetricDetails = latencyMetricDetails {
                    durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
                }
                
                asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
            }
            
            // submit the asynchronous request
            return try executeAsync(endpointOverride: endpointOverride,
                                                 endpointPath: endpointPath,
                                                 httpMethod: httpMethod,
                                                 input: input,
                                                 completion: wrappingCompletion,
                                                 invocationContext: invocationContext)
    }
}
