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
//  SDKContentHeadersMiddleware.swift
//  SmokeHTTPMiddleware
//

import SwiftMiddleware
import ClientRuntime

public struct SDKContentHeadersMiddleware<Context>: MiddlewareProtocol {
    public typealias Input = SmokeSdkHttpRequestBuilder
    public typealias Output = HttpResponse
    
    let specifyContentHeadersForZeroLengthBody: Bool
    let contentType: String
    
    public init(specifyContentHeadersForZeroLengthBody: Bool, contentType: String) {
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
        self.contentType = contentType
    }
    
    public func handle(_ input: SmokeSdkHttpRequestBuilder, context: Context,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        if case .data(let bodyDataOptional) = input.body, let bodyData = bodyDataOptional {
            if bodyData.count > 0 || self.specifyContentHeadersForZeroLengthBody {
                input.withHeader(name: HttpHeaderNames.contentType, value: contentType)
                input.withHeader(name: HttpHeaderNames.contentLength, value: "\(bodyData.count)")
            }
        }
        
        return try await next(input, context)
    }
}
