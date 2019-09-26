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
import LoggerAPI

public extension HTTPClient {
    /**
     Helper type that manages the state of a retriable sync request.
     */
    private class ExecuteSyncWithOutputRetriable<InputType, OutputType>
            where InputType: HTTPRequestInputProtocol,
            OutputType: HTTPResponseOutputProtocol {
        let endpointOverride: URL?
        let endpointPath: String
        let httpMethod: HTTPMethod
        let input: InputType
        let handlerDelegate: HTTPClientChannelInboundHandlerDelegate
        let httpClient: HTTPClient
        let retryConfiguration: HTTPClientRetryConfiguration
        let retryOnError: (Swift.Error) -> Bool
        
        var retriesRemaining: Int
        
        let milliToMicroSeconds = 1000
        
        init(endpointOverride: URL?, endpointPath: String, httpMethod: HTTPMethod,
             input: InputType,
             handlerDelegate: HTTPClientChannelInboundHandlerDelegate,
             httpClient: HTTPClient,
             retryConfiguration: HTTPClientRetryConfiguration,
             retryOnError: @escaping (Swift.Error) -> Bool) {
            self.endpointOverride = endpointOverride
            self.endpointPath = endpointPath
            self.httpMethod = httpMethod
            self.input = input
            self.handlerDelegate = handlerDelegate
            self.httpClient = httpClient
            self.retryConfiguration = retryConfiguration
            self.retriesRemaining = retryConfiguration.numRetries
            self.retryOnError = retryOnError
        }
        
        func executeSyncWithOutput() throws -> OutputType {
            do {
                // submit the synchronous request
                return try httpClient.executeSyncWithOutput(endpointOverride: endpointOverride,
                                                              endpointPath: endpointPath, httpMethod: httpMethod,
                                                              input: input, handlerDelegate: handlerDelegate)
            } catch {
                return try completeOnError(error: error)
            }
        }
        
        func completeOnError(error: Error) throws -> OutputType {
            let shouldRetryOnError = retryOnError(error)
            
            // if there are retries remaining and we should retry on this error
            if retriesRemaining > 0 && shouldRetryOnError {
                // determine the required interval
                let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: retriesRemaining))
                
                let currentRetriesRemaining = retriesRemaining
                retriesRemaining -= 1
                
                Log.debug("Request failed with error: \(error). Remaining retries: \(currentRetriesRemaining). "
                        + "Retrying in \(retryInterval) ms.")
                usleep(useconds_t(retryInterval * milliToMicroSeconds))
                Log.debug("Reattempting request due to remaining retries: \(currentRetriesRemaining)")
                return try executeSyncWithOutput()
            } else {
                if !shouldRetryOnError {
                    Log.debug("Request not retried due to error returned: \(error)")
                } else {
                    Log.debug("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
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
        - handlerDelegate: the delegate used to customize the request's channel handler.
        - retryConfiguration: the retry configuration for this request.
        - retryOnError: function that should return if the provided error is retryable.
     */
    func executeSyncRetriableWithOutput<InputType, OutputType>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        handlerDelegate: HTTPClientChannelInboundHandlerDelegate,
        retryConfiguration: HTTPClientRetryConfiguration,
        retryOnError: @escaping (Swift.Error) -> Bool) throws -> OutputType
        where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {

            let retriable = ExecuteSyncWithOutputRetriable<InputType, OutputType>(
                endpointOverride: endpointOverride, endpointPath: endpointPath,
                httpMethod: httpMethod, input: input,
                handlerDelegate: handlerDelegate, httpClient: self,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnError)
            
            return try retriable.executeSyncWithOutput()
    }
}
