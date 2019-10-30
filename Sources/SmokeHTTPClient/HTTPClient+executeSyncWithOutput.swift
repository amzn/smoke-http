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
//  HTTPClient+executeSyncWithOutput.swift
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
     Submits a request that will return a response body to this client synchronously.
     
     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     - Returns: the response body.
     - Throws: If an error occurred during the request.
     */
    func executeSyncWithOutput<InputType, OutputType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> OutputType
        where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {
            
            var responseResult: Result<OutputType, HTTPClientError>?
            let completedSemaphore = DispatchSemaphore(value: 0)
            
            let completion: (Result<OutputType, HTTPClientError>) -> () = { result in
                responseResult = result
                completedSemaphore.signal()
            }
            
            let channelFuture = try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                // the completion handler can be safely executed on a SwiftNIO thread
                asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<Result<OutputType, HTTPClientError>>(),
                handlerDelegate: handlerDelegate)
            
            channelFuture.whenComplete { result in
                switch result {
                case .success(let channel):
                    channel.closeFuture.whenComplete { _ in
                        // if this channel is being closed and no response has been recorded
                        if responseResult == nil {
                            responseResult = .failure(HTTPClient.unexpectedClosureType)
                            completedSemaphore.signal()
                        }
                    }
                case .failure(let error):
                    // there was an issue creating the channel
                    responseResult = .failure(HTTPClientError(responseCode: 500, cause: error))
                    completedSemaphore.signal()
                }
            }
            
            Log.verbose("Waiting for response from \(endpointOverride?.host ?? endpointHostName) ...")
            completedSemaphore.wait()
            
            guard let result = responseResult else {
                throw HTTPError.connectionError("Http request was closed without returning a response.")
            }
            
            Log.verbose("Got response from \(endpointOverride?.host ?? endpointHostName) - response received: \(result)")
            
            switch result {
            case .failure(let error):
                throw error
            case .success(let response):
                return response
            }
    }
}
