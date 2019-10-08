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
//  HTTPClient+executeAsyncWithoutOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import LoggerAPI

public extension HTTPClient {
    /**
     Submits a request that will not return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.
     
     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with an error if one occurs or nil otherwise.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    func executeAsyncWithoutOutput<InputType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (Error?) -> (),
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
        where InputType: HTTPRequestInputProtocol {
            return try executeAsyncWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<Error?>(),
                handlerDelegate: handlerDelegate)
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously.
     
     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with an error if one occurs or nil otherwise.
     - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    func executeAsyncWithoutOutput<InputType, InvocationStrategyType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (Error?) -> (),
        asyncResponseInvocationStrategy: InvocationStrategyType,
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
        where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Error? {
            
            var hasComplete = false
            // create a wrapping completion handler to pass to the ChannelInboundHandler
            let wrappingCompletion: (Result<HTTPResponseComponents, HTTPClientError>) -> () = { (rawResult) in
                let result: HTTPClientError?
                
                switch rawResult {
                case .failure(let error):
                    // its an error, complete with this error
                    result = error
                case .success:
                    // its a successful completion, complete with an empty error.
                    result = nil
                }
                
                asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
                hasComplete = true
            }
            
            // submit the asynchronous request
            let channel = try executeAsync(endpointOverride: endpointOverride,
                                           endpointPath: endpointPath,
                                           httpMethod: httpMethod,
                                           input: input,
                                           completion: wrappingCompletion,
                                           handlerDelegate: handlerDelegate)
            
            channel.closeFuture.whenComplete { result in
                // if this channel is being closed and no response has been recorded
                if !hasComplete {
                    completion(HTTPClient.unexpectedClosureType)
                }
            }
            
            return channel
    }
}
