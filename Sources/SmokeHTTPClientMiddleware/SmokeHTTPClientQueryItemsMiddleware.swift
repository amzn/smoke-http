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
//  SmokeHTTPClientQueryItemsMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import Foundation
import HttpMiddleware
import HttpClientMiddleware
import AsyncHTTPClient
import SmokeHTTPTypes
import QueryCoding

public struct SmokeHTTPClientQueryItemsMiddleware<OperationInputType: HTTPRequestInputProtocol>: QueryItemMiddlewareProtocol {
    public typealias InputType = SerializeClientRequestMiddlewarePhaseInput<OperationInputType, HTTPClientRequest>
    public typealias OutputType = HTTPClientResponse
    
    private let encoder: QueryEncoder
    private let allowedCharacterSet: CharacterSet?
    
    public init(encoder: QueryEncoder,
                allowedCharacterSet: CharacterSet? = nil) {
        self.encoder = encoder
        self.allowedCharacterSet = allowedCharacterSet
    }
    
    public func handle<HandlerType>(input phaseInput: InputType, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : HandlerProtocol, InputType == HandlerType.InputType, HTTPClientResponse == HandlerType.OutputType {
        if let queryEncodable = phaseInput.input.queryEncodable {
            let urlQueryItems = try self.encoder.asURLQueryItems(queryEncodable,
                                                                      allowedCharacterSet: self.allowedCharacterSet)
            
            phaseInput.builder.withQueryItems(urlQueryItems)
        }
        
        return try await next.handle(input: phaseInput)
    }
}
