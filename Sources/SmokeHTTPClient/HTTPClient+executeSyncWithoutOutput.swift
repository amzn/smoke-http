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
import Logging

public extension HTTPClient {
    
    /**
     Submits a request that will not return a response body to this client synchronously.
     
     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - invocationContext: context to use for this invocation.
         - Throws: If an error occurred during the request.
     */
    func executeSyncWithoutOutput<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientChannelInboundHandlerDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws
        where InputType: HTTPRequestInputProtocol {
            var responseError: HTTPClientError?
            let completedSemaphore = DispatchSemaphore(value: 0)
            
            let completion: (HTTPClientError?) -> () = { error in
                if let error = error {
                    responseError = HTTPClientError(responseCode: 500, cause: error)
                }
                completedSemaphore.signal()
            }
            
            let channelFuture = try executeAsyncWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                // the completion handler can be safely executed on a SwiftNIO thread
                asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<HTTPClientError?>(),
                invocationContext: invocationContext)
            
            channelFuture.whenComplete { result in
                switch result {
                case .success(let channel):
                    channel.closeFuture.whenComplete { _ in
                        // if this channel is being closed and no response has been recorded
                        if responseError == nil {
                            responseError = HTTPClientError(responseCode: 500,
                                                            cause: HTTPClient.unexpectedClosureType)
                            completedSemaphore.signal()
                        }
                    }
                case .failure(let error):
                    // there was an issue creating the channel
                    responseError = HTTPClientError(responseCode: 500, cause: error)
                    completedSemaphore.signal()
                }
            }
            
            completedSemaphore.wait()
            
            if let error = responseError {
                throw error
            }
    }
}
