// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  SmokeHTTPClientAdditionalHeadersMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import HttpMiddleware
import HttpClientMiddleware
import AsyncHTTPClient
import NIOHTTP1
import SmokeHTTPTypes
import HTTPHeadersCoding

public struct SmokeHTTPClientAdditionalHeadersMiddleware<OperationInputType: HTTPRequestInputProtocol>: MiddlewareProtocol {
    public var id: String = "SmokeAdditionalHeaders"
    
    public typealias InputType = SerializeClientRequestMiddlewarePhaseInput<OperationInputType, HTTPClientRequest>
    public typealias OutputType = HTTPClientResponse
    
    private let encoder: HTTPHeadersEncoder
    
    public init(encoder: HTTPHeadersEncoder) {
        self.encoder = encoder
    }
    
    public func handle<HandlerType>(input phaseInput: InputType,
                                    context: MiddlewareContext, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : MiddlewareHandlerProtocol, InputType == HandlerType.InputType, HTTPClientResponse == HandlerType.OutputType {
        if let additionalHeadersEncodable = phaseInput.input.additionalHeadersEncodable {
            let headers = try self.encoder.encode(additionalHeadersEncodable)
            
            let rawHeaders: [(String, String)] = headers.compactMap { entry in
                guard let value = entry.1 else {
                    return nil
                }
                
                return (entry.0, value)
            }
            
            let additionalHeaders = HTTPHeaders(rawHeaders)
            phaseInput.builder.withHeaders(additionalHeaders)
        }
        
        return try await next.handle(input: phaseInput, context: context)
    }
}
