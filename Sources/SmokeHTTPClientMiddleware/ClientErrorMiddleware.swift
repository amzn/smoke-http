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
//  ClientErrorMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import Foundation
import HttpClientMiddleware
import NIOHTTP1
import NIOFoundationCompat
import SmokeHTTPTypes
import AsyncHTTPClient
import AsyncHttpMiddlewareClient

public struct ClientErrorMiddleware: MiddlewareProtocol {
    public var id = "ClientError"
    
    public typealias InputType = HTTPClientRequest
    public typealias OutputType = HTTPClientResponse
    
    public init() {
    }
    
    public func handle<HandlerType>(input: HTTPClientRequest, next: HandlerType) async throws
    -> HTTPClientResponse
    where HandlerType : HandlerProtocol, HTTPClientRequest == HandlerType.InputType,
    HTTPClientResponse == HandlerType.OutputType {
        do {
            return try await next.handle(input: input)
        } catch {
            let wrappingError: SmokeHTTPTypes.HTTPClientError
                        
            switch error {
            // for retriable HTTPClientErrors
            case let clientError as AsyncHTTPClient.HTTPClientError where Self.isRetriableHTTPClientError(clientError: clientError):
                wrappingError = HTTPClientError(responseCode: 500, cause: clientError)
            // for non-retriable HTTPClientErrors
            case let clientError as AsyncHTTPClient.HTTPClientError:
                wrappingError = HTTPClientError(responseCode: 400, cause: clientError)
            // by default treat all other errors as 500 so they can be retried
            default:
                wrappingError = HTTPClientError(responseCode: 500, cause: error)
            }

            // complete with this error
            throw wrappingError
        }
    }
    
    public static func isRetriableHTTPClientError(clientError: AsyncHTTPClient.HTTPClientError) -> Bool {
        // special case read, connect, connection pool or tls handshake timeouts and remote connection closed errors
        // to a 500 error to allow for retries
        if clientError == AsyncHTTPClient.HTTPClientError.readTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.connectTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.tlsHandshakeTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.remoteConnectionClosed
                || clientError == AsyncHTTPClient.HTTPClientError.getConnectionFromPoolTimeout {
            return true
        }
        
        return false
    }
}
