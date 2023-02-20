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
//  SDKHeaderMiddleware.swift
//  SmokeHTTPMiddleware
//

import SwiftMiddleware
import ClientRuntime

public struct HttpHeaderNames {
    /// Content-Length Header
    static let contentLength = "Content-Length"

    /// Content-Type Header
    static let contentType = "Content-Type"
    
    static let userAgent = "User-Agent"
    
    static let accept = "Accept"
}

public struct SDKHeaderMiddleware<Context>: MiddlewareProtocol {
    public typealias Input = SdkHttpRequestBuilder
    public typealias Output = HttpResponse
    
    let key: String
    let value: String
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
    
    public static var userAgent: Self {
        Self(key: HttpHeaderNames.userAgent, value: "SmokeHTTPClient")
    }
    
    public static var accept: Self {
        Self(key: HttpHeaderNames.accept, value: "*/*")
    }
    
    public func handle(_ input: SdkHttpRequestBuilder, context: Context,
                       next: (SdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        input.withHeader(name: self.key, value: self.value)
        
        return try await next(input, context)
    }
}
