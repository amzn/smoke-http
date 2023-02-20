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
//  SmokeHTTPMiddleware.swift
//  SmokeHTTPMiddleware
//

import ClientRuntime
import SwiftMiddleware

/**
 Executes requests on a http client engine, with a delegate applying a standard middleware stack.
 */
public struct SmokeHTTPMiddleware {
    /// Delegate the applies the standard middleware stack to requests
    public let delegate: SmokeHTTPMiddlewareDelegate
    
    private let engine: HttpClientEngine
    
    /**
     Initializer.
     - Parameters:
         - delegate: Delegate the applies the standard middleware stack to requests
         - runtimeConfig: The runtime configuration to use for the http client engine.
     */
    public init(delegate: SmokeHTTPMiddlewareDelegate,
                runtimeConfig: ClientRuntime.SDKRuntimeConfiguration) {
        self.delegate = delegate
        self.engine = runtimeConfig.httpClientEngine
    }
}
 
extension SmokeHTTPMiddleware {
    /**
     Executes a request that will transform the input and output.
     
     - Parameters:
         - outerMiddleware: The request-specific middleware to be applied before the request/response transform.
         - innerMiddleware: The request-specific middleware to be applied after the request/response transform.
         - input: The pre-transformed input for the request.
         - endpointOverride: If there is an endpoint override for the request.
         - endpointPath: The endpoint path for the request.
         - httpMethod: The http method for the request.
         - context: The context that will be passed to all middleware.
     - Returns:
         The post transformed output of the reqest having been made.
     */
    func execute<OriginalInput, TransformedOutput, InnerMiddlwareType: MiddlewareProtocol, OuterMiddlwareType: MiddlewareProtocol,  Context>(
        outerMiddleware: OuterMiddlwareType, innerMiddleware: InnerMiddlwareType,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType,
        context: Context) -> TransformedOutput
    where InnerMiddlwareType.Input == OriginalInput, InnerMiddlwareType.Output == TransformedOutput,
    OuterMiddlwareType.Input == SdkHttpRequestBuilder, OuterMiddlwareType.Output == HttpResponse,
    InnerMiddlwareType.Context == Context, OuterMiddlwareType.Context == Context {
        return self.delegate.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                     endpointOverride: endpointOverride, endpointPath: endpointPath,
                                     httpMethod: httpMethod, context: context) { requestBuilder, context in
            let request = requestBuilder.build()
            
            return try await self.engine.execute(request: request)
        }
    }
}
