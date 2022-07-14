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
//  JSONTypedErrorMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import Foundation
import HttpMiddleware
import HttpClientMiddleware
import NIOHTTP1
import NIOFoundationCompat
import SmokeHTTPTypes
import AsyncHTTPClient
import AsyncHttpMiddlewareClient

public enum TypedErrorDecodingError: Error {
    case decodingFailed(cause: Swift.Error, bodyString: String)
}

public struct JSONTypedErrorMiddleware<ErrorType: Decodable & Error>: MiddlewareProtocol {
    public var id = "JSONTypedError"
    
    public typealias InputType = HTTPClientRequest
    public typealias OutputType = HTTPClientResponse
    
    private let decoder: JSONDecoder
    private let maxBytes: Int
    
    public init(maxBytes: Int, decoder: JSONDecoder = .init()) {
        self.maxBytes = maxBytes
        self.decoder = decoder
    }
    
    public func handle<HandlerType>(input: HTTPClientRequest,
                                    context: MiddlewareContext, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : MiddlewareHandlerProtocol, HTTPClientRequest == HandlerType.InputType,
    HTTPClientResponse == HandlerType.OutputType {
        let response = try await next.handle(input: input, context: context)
        
        let isSuccess: Bool
        switch response.status {
        case .ok, .created, .accepted, .nonAuthoritativeInformation, .noContent, .resetContent, .partialContent:
            isSuccess = true
        default:
            isSuccess = false
        }
        
        guard !isSuccess else {
            // nothing to do
            return response
        }
        
        var bodyBuffer = try await response.body.collect(upTo: self.maxBytes)
        
        let byteBufferSize = bodyBuffer.readableBytes
        guard let bodyData = bodyBuffer.readData(length: byteBufferSize) else {
            throw DeserializationError.missingBody(response)
        }
        
        let cause: ErrorType
        do {
            cause = try self.decoder.decode(ErrorType.self, from: bodyData)
        } catch {
            let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
            throw SmokeHTTPTypes.HTTPClientError(responseCode: Int(response.status.code),
                                                 cause: TypedErrorDecodingError.decodingFailed(cause: error,
                                                                                               bodyString: bodyString))
        }
        
        throw SmokeHTTPTypes.HTTPClientError(responseCode: Int(response.status.code), cause: cause)
    }
}
