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
//  HTTPClient+executeAsyncRetriableWithoutOutput.swift
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
     Helper type that manages the state of a retriable async request.
     */
    private class ExecuteAsyncWithoutOutputRetriable<InputType, InvocationStrategyType>
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
            InvocationStrategyType.OutputType == Error? {
        let endpointOverride: URL?
        let endpointPath: String
        let httpMethod: HTTPMethod
        let input: InputType
        let outerCompletion: (Error?) -> ()
        let asyncResponseInvocationStrategy: InvocationStrategyType
        let handlerDelegate: HTTPClientChannelInboundHandlerDelegate
        let httpClient: HTTPClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (Swift.Error) -> Bool
        let queue = DispatchQueue.global()
        
        var retriesRemaining: Int
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod,
             input: InputType, outerCompletion: @escaping (Error?) -> (),
             asyncResponseInvocationStrategy: InvocationStrategyType,
             handlerDelegate: HTTPClientChannelInboundHandlerDelegate,
             httpClient: HTTPClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (Swift.Error) -> Bool) {
            self.endpointOverride = endpointOverride
            self.endpointPath = endpointPath
            self.httpMethod = httpMethod
            self.input = input
            self.outerCompletion = outerCompletion
            self.asyncResponseInvocationStrategy = asyncResponseInvocationStrategy
            self.handlerDelegate = handlerDelegate
            self.httpClient = httpClient
            self.retryConfiguration = retryConfiguration
            self.retryOnError = retryOnError
            self.retriesRemaining = retryConfiguration.numRetries
        }
        
        func executeAsyncWithoutOutput() throws {
            // submit the asynchronous request
            _ = try httpClient.executeAsyncWithoutOutput(endpointOverride: endpointOverride,
                                                         endpointPath: endpointPath, httpMethod: httpMethod,
                                                         input: input, completion: completion,
                                                         asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                                                         handlerDelegate: handlerDelegate)
        }
        
        func completion(innerError: Error?) {
            let error: Error?

            if let innerError = innerError {
                let shouldRetryOnError = retryOnError(innerError)
                
                // if there are retries remaining and we should retry on this error
                if retriesRemaining > 0 && shouldRetryOnError {
                    // determine the required interval
                    let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                    
                    let currentRetriesRemaining = retriesRemaining
                    retriesRemaining -= 1
                    
                    Log.warning("Request failed with error: \(innerError). Remaining retries: \(currentRetriesRemaining). "
                        + "Retrying in \(retryInterval) ms.")
                    let deadline = DispatchTime.now() + .milliseconds(retryInterval)
                    queue.asyncAfter(deadline: deadline) {
                        Log.debug("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                        do {
                            // execute again
                            try self.executeAsyncWithoutOutput()
                            return
                        } catch {
                            // its attempting to retry causes an error; complete with the provided error
                            self.outerCompletion(innerError)
                        }
                    }
                    
                    // request will be retried; don't complete yet
                    return
                }
                
                if !shouldRetryOnError {
                    Log.debug("Request not retried due to error returned: \(innerError)")
                } else {
                    Log.debug("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
                }
                
                // its an error; complete with the provided error
                error = innerError
            } else {
                error = innerError
            }

            outerCompletion(error)
        }
    }
    
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
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeAsyncRetriableWithoutOutput<InputType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (Error?) -> (),
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (Swift.Error) -> Bool) throws
        where InputType: HTTPRequestInputProtocol {
            try executeAsyncRetriableWithoutOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<Error?>(),
                handlerDelegate: handlerDelegate,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
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
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeAsyncRetriableWithoutOutput<InputType, InvocationStrategyType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        completion: @escaping (Error?) -> (),
        asyncResponseInvocationStrategy: InvocationStrategyType,
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (Swift.Error) -> Bool) throws
        where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Error? {

            let retriable = ExecuteAsyncWithoutOutputRetriable(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input, outerCompletion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                handlerDelegate: handlerDelegate, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            try retriable.executeAsyncWithoutOutput()
    }
}
