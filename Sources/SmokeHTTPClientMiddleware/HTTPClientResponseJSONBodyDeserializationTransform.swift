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
//  HTTPClientResponseJSONBodyDeserializationTransform.swift
//  SmokeHTTPClientMiddleware
//

import Foundation
import HttpMiddleware
import HttpClientMiddleware
import AsyncHTTPClient
import NIO
import NIOFoundationCompat
import AsyncHttpMiddlewareClient
import SmokeHTTPTypes
import HTTPHeadersCoding
import Logging

public enum DeserializationError: Error {
    case missingBody(HTTPClientResponse)
}

public struct HTTPClientResponseJSONBodyDeserializationTransform<OutputType: HTTPResponseOutputProtocol>: DeserializationTransformProtocol {
    public typealias HTTPResponseType = HTTPClientResponse
    
    private let jsonDecoder: JSONDecoder
    private let headersDecoder: HTTPHeadersDecoder
    private let logger: Logger
    private let maxBytes: Int
    
    public init(maxBytes: Int, logger: Logger,
                jsonDecoder: JSONDecoder,
                headersDecoder: HTTPHeadersDecoder) {
        self.maxBytes = maxBytes
        self.logger = logger
        self.jsonDecoder = jsonDecoder
        self.headersDecoder = headersDecoder
    }
    
    public func transform(input: HTTPClientResponse) async throws -> OutputType {
        var bodyBuffer = try await input.body.collect(upTo: self.maxBytes)
        
        // Convert output to a debug string only if debug logging is enabled
        self.logger.trace("Attempting to decode from HTTPClientResponse.",
                          metadata: ["inputFormat": "JSON",
                                     "outputType": "\(OutputType.self)"])
        
        func bodyDecodableProvider() throws -> OutputType.BodyType {
            let byteBufferSize = bodyBuffer.readableBytes
            guard let bodyData = bodyBuffer.readData(length: byteBufferSize) else {
                throw DeserializationError.missingBody(input)
            }
            
            self.logger.trace("Attempting to decode body.",
                              metadata: ["inputFormat": "JSON",
                                         "outputType": "\(OutputType.BodyType.self)",
                                         "bodyData": "\(bodyData.debugString)"])
            
            return try self.jsonDecoder.decode(OutputType.BodyType.self, from: bodyData)
        }
        
        let mappedHeaders: [(String, String?)] = input.headers.map { ($0.0, $0.1) }
        func headersDecodableProvider() throws -> OutputType.HeadersType {
            self.logger.trace("Attempting to decode headers.",
                              metadata: ["inputFormat": "HTTPHeaders",
                                         "outputType": "\(OutputType.HeadersType.self)",
                                         "bodyData": "\(mappedHeaders)"])
            
            return try self.headersDecoder.decode(OutputType.HeadersType.self,
                                                  from: mappedHeaders)
        }
        
        let result = try OutputType.compose(bodyDecodableProvider: bodyDecodableProvider,
                                            headersDecodableProvider: headersDecodableProvider)
                
        self.logger.trace("Output type composed.",
                          metadata: ["inputFormat": "JSON",
                                     "outputType": "\(OutputType.self)"])
                
        return result
    }
}

