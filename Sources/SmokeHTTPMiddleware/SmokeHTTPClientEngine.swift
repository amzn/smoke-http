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
//  SmokeHTTPClientEngine.swift
//  SmokeHTTPMiddleware
//

import ClientRuntime
import SwiftMiddleware

/**
 Executes requests on a http client engine.
 */
public struct SmokeHTTPClientEngine {
    private let engine: HttpClientEngine
    
    /**
     Initializer.
     - Parameters:
         - delegate: Delegate the applies the standard middleware stack to requests
         - runtimeConfig: The runtime configuration to use for the http client engine.
     */
    public init(runtimeConfig: ClientRuntime.SDKRuntimeConfiguration) {
        self.engine = runtimeConfig.httpClientEngine
    }
    
    public func getExecuteFunction<Context>() -> ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) {
        func executeFunction(requestBuilder: SmokeSdkHttpRequestBuilder, context: Context) async throws -> HttpResponse {
            let request = requestBuilder.build()
            
            return try await self.engine.execute(request: request)
        }
        
        return executeFunction
    }
}
