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
//  HTTPClient+executeAsyncWithOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOOpenSSL
import NIOTLS
import LoggerAPI

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
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    func executeAsyncWithOutput<InputType, OutputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<OutputType>) -> (),
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
        where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
            return try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<HTTPResult<OutputType>>(),
                handlerDelegate: handlerDelegate)
    }

    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with the response body or any error.
     - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    func executeAsyncWithOutput<InputType, OutputType, InvocationStrategyType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<OutputType>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == HTTPResult<OutputType>,
        OutputType: HTTPResponseOutputProtocol {

        var hasComplete = false
        let requestDelegate = clientDelegate
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        // that will decode the returned body into the desired decodable type.
        let wrappingCompletion: (HTTPResult<HTTPResponseComponents>) -> () = { (rawResult) in
            let result: HTTPResult<OutputType>

            switch rawResult {
            case .error(let error):
                // its an error; complete with the provided error
                result = .error(error)
            case .response(let response):
                do {
                    // decode the provided body into the desired type
                    let output: OutputType = try requestDelegate.decodeOutput(
                        output: response.body,
                        headers: response.headers)

                    // complete with the decoded type
                    result = .response(output)
                } catch {
                    // if there was a decoding error, complete with that error
                    result = .error(error)
                }
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

        channel.closeFuture.whenComplete {
            // if this channel is being closed and no response has been recorded
            if !hasComplete {
                completion(.error(HTTPClient.unexpectedClosureType))
            }
        }

        return channel
    }
}
