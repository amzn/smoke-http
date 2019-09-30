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
//  HTTPClient+executeSyncWithoutOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import LoggerAPI

public extension HTTPClient {
    private struct AsyncErrorResult {
        let error: Error?
    }
    
    /**
     Submits a request that will not return a response body to this client synchronously.
     
     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     - Throws: If an error occurred during the request.
     */
    func executeSyncWithoutOutput<InputType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws
        where InputType: HTTPRequestInputProtocol {
            var responseError: AsyncErrorResult?
            let completedSemaphore = DispatchSemaphore(value: 0)
            
            let completion: (Error?) -> () = { error in
                responseError = AsyncErrorResult(error: error)
                completedSemaphore.signal()
            }
            
            let channelFuture = try executeAsyncWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                // the completion handler can be safely executed on a SwiftNIO thread
                asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<Error?>(),
                handlerDelegate: handlerDelegate)
            
            channelFuture.whenComplete { result in
                switch result {
                case .success(let channel):
                    channel.closeFuture.whenComplete { _ in
                        // if this channel is being closed and no response has been recorded
                        if responseError == nil {
                            responseError = AsyncErrorResult(error: HTTPClient.unexpectedClosureType)
                            completedSemaphore.signal()
                        }
                    }
                case .failure(let error):
                    // there was an issue creating the channel
                    responseError = AsyncErrorResult(error: error)
                    completedSemaphore.signal()
                }
            }
            
            completedSemaphore.wait()
            
            if let error = responseError?.error {
                throw error
            }
    }
}
