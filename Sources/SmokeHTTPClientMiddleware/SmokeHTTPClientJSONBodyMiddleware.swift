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
//  SmokeHTTPClientJSONBodyMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import Foundation
import HttpClientMiddleware
import AsyncHTTPClient
import NIO
import NIOFoundationCompat
import SmokeHTTPTypes

public struct SmokeHTTPClientJSONBodyMiddleware<OperationInputType: HTTPRequestInputProtocol>: RequestBodyMiddlewareProtocol {
    public typealias InputType = SerializeInputMiddlewarePhaseInput<OperationInputType, HTTPClientRequest>
    public typealias OutputType = HTTPClientResponse
    
    private let encoder: JSONEncoder
    
    public init(encoder: JSONEncoder = .init()) {
        self.encoder = encoder
    }
    
    public func handle<HandlerType>(input phaseInput: InputType, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : HandlerProtocol, InputType == HandlerType.InputType, HTTPClientResponse == HandlerType.OutputType {
        if let bodyEncodable = phaseInput.input.bodyEncodable {
            let body = try self.encoder.encode(bodyEncodable)
            
            phaseInput.builder.withBody(.bytes(ByteBuffer(data: body)))
        }
        
        return try await next.handle(input: phaseInput)
    }
}
