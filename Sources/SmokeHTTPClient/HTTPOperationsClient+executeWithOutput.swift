// Copyright 2018-2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPOperationsClient+executeWithOutput.swift
//  SmokeHTTPClient
//

#if compiler(>=5.5) && canImport(_Concurrency)

import Foundation
import NIO
import NIOHTTP1

public extension HTTPOperationsClient {
    
    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - invocationContext: context to use for this invocation.
     - Returns: the response body.
     - Throws: If an error occurred during the request.
     */
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    func executeWithOutput<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws -> OutputType
    where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
        return try await executeAsEventLoopFutureWithOutput(
            endpointOverride: endpointOverride,
            endpointPath: endpointPath,
            httpMethod: httpMethod,
            input: input,
            invocationContext: invocationContext).get()
    }
}

#endif
