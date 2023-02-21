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
//  SmokeSdkHttpRequestBuilder.swift
//  SmokeHTTPMiddleware
//

import Foundation
import ClientRuntime

public class SmokeSdkHttpRequestBuilder {

    public init() {}

    public var headers: Headers = Headers()
    public var methodType: HttpMethodType = .get
    public var host: String = ""
    public var path: String = "/"
    public var body: HttpBody = .none
    public var queryItems: [URLQueryItem] = []
    public var port: Int16 = 443
    public var protocolType: ProtocolType = .https

    // We follow the convention of returning the builder object
    // itself from any configuration methods, and by adding the
    // @discardableResult attribute we won't get warnings if we
    // don't end up doing any chaining.
    @discardableResult
    public func withHeaders(_ value: Headers) -> Self {
        self.headers.addAll(headers: value)
        return self
    }

    @discardableResult
    public func withHeader(name: String, value: String) -> Self {
        self.headers.add(name: name, value: value)
        return self
    }

    @discardableResult
    public func updateHeader(name: String, value: [String]) -> Self {
        self.headers.update(name: name, value: value)
        return self
    }

    @discardableResult
    public func withMethod(_ value: HttpMethodType) -> Self {
        self.methodType = value
        return self
    }

    @discardableResult
    public func withHost(_ value: String) -> Self {
        self.host = value
        return self
    }

    @discardableResult
    public func withPath(_ value: String) -> Self {
        self.path = value
        return self
    }

    @discardableResult
    public func withBody(_ value: HttpBody) -> Self {
        self.body = value
        return self
    }

    @discardableResult
    public func withQueryItems(_ value: [URLQueryItem]) -> Self {
        self.queryItems = value
        return self
    }

    @discardableResult
    public func withQueryItem(_ value: URLQueryItem) -> Self {
        self.queryItems.append(value)
        return self
    }

    @discardableResult
    public func withPort(_ value: Int16) -> Self {
        self.port = value
        return self
    }

    @discardableResult
    public func withProtocol(_ value: ProtocolType) -> Self {
        self.protocolType = value
        return self
    }
    
    public var url: URL? {
        var components = URLComponents()
        components.scheme = protocolType.rawValue
        components.host = host
        components.path = path
        components.percentEncodedQueryItems = queryItems

        return components.url
    }

    public func build() -> SdkHttpRequest {
        let endpoint = Endpoint(host: host,
                                path: path,
                                port: port,
                                queryItems: queryItems,
                                protocolType: protocolType)
        return SdkHttpRequest(method: methodType,
                              endpoint: endpoint,
                              headers: headers,
                              queryItems: queryItems,
                              body: body)
    }
}
