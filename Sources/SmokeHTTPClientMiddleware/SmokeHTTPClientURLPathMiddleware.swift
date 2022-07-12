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
//  SmokeHTTPClientURLPathMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import HttpMiddleware
import HttpClientMiddleware
import AsyncHTTPClient
import SmokeHTTPTypes
import HTTPPathCoding

public struct SmokeHTTPClientURLPathMiddleware<OperationInputType: HTTPRequestInputProtocol>: RequestURLPathMiddlewareProtocol {
    public typealias InputType = SerializeClientRequestMiddlewarePhaseInput<OperationInputType, HTTPClientRequest>
    public typealias OutputType = HTTPClientResponse
    
    private let encoder: HTTPPathEncoder
    private let httpPath: String
    
    public init(encoder: HTTPPathEncoder,
                httpPath: String) {
        self.encoder = encoder
        self.httpPath = httpPath
    }
    
    public func handle<HandlerType>(input phaseInput: InputType, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : HandlerProtocol, InputType == HandlerType.InputType, HTTPClientResponse == HandlerType.OutputType {
        let pathPostfix = phaseInput.input.pathPostfix ?? ""
        
        let pathTemplate = "\(self.httpPath)\(pathPostfix)"
        let path: String
        if let pathEncodable = phaseInput.input.pathEncodable {
            path = try self.encoder.encode(pathEncodable,
                                           withTemplate: pathTemplate)
        } else {
            path = pathTemplate
        }
        phaseInput.builder.withPath(path)
        
        return try await next.handle(input: phaseInput)
    }
}
