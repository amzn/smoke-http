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
//  SDKHTTPHostNameMiddleware.swift
//  SmokeHTTPMiddleware
//

import SwiftMiddleware
import ClientRuntime

public struct SDKHTTPHostNameMiddleware<Context>: MiddlewareProtocol {
    public typealias Input = SmokeSdkHttpRequestBuilder
    public typealias Output = HttpResponse
    
    let hostName: String
    
    public init(hostName: String) {
        self.hostName = hostName
    }
    
    public func handle(_ input: SmokeSdkHttpRequestBuilder, context: Context,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        input.withHost(self.hostName)
        
        return try await next(input, context)
    }
}
