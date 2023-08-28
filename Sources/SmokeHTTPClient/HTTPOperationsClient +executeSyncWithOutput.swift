// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPOperationsClient+executeSyncWithOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import Logging

public extension HTTPOperationsClient {
    /**
     Submits a request that will return a response body to this client synchronously.
     
     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - invocationContext: context to use for this invocation.
         - Returns: the response body.
         - Throws: If an error occurred during the request.
     */
    func executeSyncWithOutput<InputType, OutputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> OutputType
    where InputType: HTTPRequestInputProtocol,
        OutputType: HTTPResponseOutputProtocol {
            let requestComponents = try clientDelegate.encodeInputAndQueryString(
                input: input,
                httpPath: endpointPath,
                invocationReporting: invocationContext.reporting)
            let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
            let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
            
            return try executeSyncWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                invocationContext: wrappingInvocationContext)
    }
    
    /**
     Submits a request that will return a response body to this client synchronously. To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.
     
     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - invocationContext: context to use for this invocation.
         - Returns: the response body.
         - Throws: If an error occurred during the request.
     */
    internal func executeSyncWithOutputWithWrappedInvocationContext<OutputType, InvocationReportingType: HTTPClientInvocationReporting,
            HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        requestComponents: HTTPRequestComponents,
        httpMethod: HTTPMethod,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> OutputType
        where OutputType: HTTPResponseOutputProtocol {
            
            var responseResult: Result<OutputType, HTTPClientError>?
            let completedSemaphore = DispatchSemaphore(value: 0)
            
            let completion: (Result<OutputType, HTTPClientError>) -> () = { result in
                responseResult = result
                completedSemaphore.signal()
            }
            
            _ = try executeAsyncWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                completion: completion,
                // the completion handler can be safely executed on a SwiftNIO thread
                asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<Result<OutputType, HTTPClientError>>(),
                invocationContext: invocationContext)
            
            let logger = invocationContext.reporting.logger
            logger.trace("Waiting for response from \(endpointOverride?.host ?? endpointHostName) ...")
            completedSemaphore.wait()
            
            guard let result = responseResult else {
                throw HTTPError.connectionError("Http request was closed without returning a response.")
            }
            
            logger.trace("Got response from \(endpointOverride?.host ?? endpointHostName) - response received: \(result)")
            
            switch result {
            case .failure(let error):
                throw error
            case .success(let response):
                return response
            }
    }
}
