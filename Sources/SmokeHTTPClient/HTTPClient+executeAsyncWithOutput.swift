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
//  HTTPClient+executeAsyncWithOutput.swift
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
     Submits a request that will return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with the response body or any error.
        - invocationContext: context to use for this invocation.
     */
    func executeAsyncWithOutput<InputType, OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<Channel>
        where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
            return try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<Result<OutputType, HTTPClientError>>(),
                invocationContext: invocationContext)
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
     */
    func executeAsyncWithOutput<InputType, OutputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<Channel>
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Result<OutputType, HTTPClientError>,
        OutputType: HTTPResponseOutputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
            
            return try executeAsyncWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: wrappingInvocationContext)
    }

    /**
     Submits a request that will return a response body to this client asynchronously. To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
     */
    internal func executeAsyncWithOutputWithWrappedInvocationContext<InputType, OutputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<Channel>
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Result<OutputType, HTTPClientError>,
        OutputType: HTTPResponseOutputProtocol {
            
        let durationMetricDetails: (Date, Metrics.Timer)?
        if let durationTimer = invocationContext.reporting.latencyTimer {
            durationMetricDetails = (Date(), durationTimer)
        } else {
            durationMetricDetails = nil
        }

        var hasComplete = false
        let requestDelegate = clientDelegate
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        // that will decode the returned body into the desired decodable type.
        let wrappingCompletion: (Result<HTTPResponseComponents, HTTPClientError>) -> () = { (rawResult) in
            let result: Result<OutputType, HTTPClientError>

            switch rawResult {
            case .failure(let error):
                // its an error; complete with the provided error
                result = .failure(error)
                
                // report failure metric
                switch error.category {
                case .clientError:
                    invocationContext.reporting.failure4XXCounter?.increment()
                case .serverError:
                    invocationContext.reporting.failure5XXCounter?.increment()
                }
            case .success(let response):
                do {
                    // decode the provided body into the desired type
                    let output: OutputType = try requestDelegate.decodeOutput(
                        output: response.body,
                        headers: response.headers,
                        invocationReporting: invocationContext.reporting)

                    // complete with the decoded type
                    result = .success(output)
                    
                    // report success metric
                    invocationContext.reporting.successCounter?.increment()
                } catch {
                    // if there was a decoding error, complete with that error
                    result = .failure(HTTPClientError(responseCode: 400, cause: error))
                    
                    // report success metric
                    invocationContext.reporting.failure4XXCounter?.increment()
                }
            }
            
            if let durationMetricDetails = durationMetricDetails {
                durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
            }

            asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
            hasComplete = true
        }

        // submit the asynchronous request
        let channelFuture = try executeAsync(endpointOverride: endpointOverride,
                                             endpointPath: endpointPath,
                                             httpMethod: httpMethod,
                                             input: input,
                                             completion: wrappingCompletion,
                                             invocationContext: invocationContext)
            
        channelFuture.whenComplete { result in
            switch result {
            case .success(let channel):
                channel.closeFuture.whenComplete { _ in
                    // if this channel is being closed and no response has been recorded
                    if !hasComplete {
                        completion(.failure(HTTPClient.unexpectedClosureType))
                    }
                }
            case .failure(let error):
                // there was an issue creating the channel
                completion(.failure(HTTPClientError(responseCode: 500, cause: error)))
            }
        }

        return channelFuture
    }
}
