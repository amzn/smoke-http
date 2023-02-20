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
//  SmokeHTTPMiddlewareDelegate.swift
//  SmokeHTTPMiddleware
//

import SwiftMiddleware
import ClientRuntime

/**
 Delegate protocol that handles applying a standard transforming middleware stack to a request.
 */
public protocol SmokeHTTPMiddlewareDelegate {

    /**
     Executes a request by applying a standard transforming middleware stack.
     
     - Parameters:
         - outerMiddleware: The request-specific middleware to be applied before the request/response transform.
         - innerMiddleware: The request-specific middleware to be applied after the request/response transform.
         - input: The pre-transformed input for the request.
         - endpointOverride: If there is an endpoint override for the request.
         - endpointPath: The endpoint path for the request.
         - httpMethod: The http method for the request.
         - context: The context that will be passed to all middleware.
         - next: The function that should be called after the middleware stack has been run to actually process the request
     - Returns:
         The post transformed output of the reqest having been made.
     */
    func execute<OriginalInput, TransformedOutput, InnerMiddlwareType: MiddlewareProtocol, OuterMiddlwareType: MiddlewareProtocol,  Context>(
        outerMiddleware: OuterMiddlwareType?, innerMiddleware: InnerMiddlwareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        next: (SdkHttpRequestBuilder, Context) async throws -> HttpResponse) -> TransformedOutput
    where InnerMiddlwareType.Input == OriginalInput, InnerMiddlwareType.Output == TransformedOutput,
          OuterMiddlwareType.Input == SdkHttpRequestBuilder, OuterMiddlwareType.Output == HttpResponse,
          InnerMiddlwareType.Context == Context, OuterMiddlwareType.Context == Context
    
}
