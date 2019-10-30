// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPRequestInput.swift
//  SmokeHTTPClient
//

import Foundation

/**
 A HTTP Request that includes a query, path, body and additional headers
 */
public struct HTTPRequestInput<QueryType: Encodable,
                               PathType: Encodable,
                               BodyType: Encodable,
                               AdditionalHeadersType: Encodable>: HTTPRequestInputProtocol {
    public let queryEncodable: QueryType?
    public let pathEncodable: PathType?
    public let bodyEncodable: BodyType?
    public let additionalHeadersEncodable: AdditionalHeadersType?
    public let pathPostfix: String?

    public init(queryEncodable: QueryType? = nil,
                pathEncodable: PathType? = nil,
                bodyEncodable: BodyType? = nil,
                additionalHeaders: AdditionalHeadersType? = nil,
                pathPostfix: String? = nil) {
        self.queryEncodable = queryEncodable
        self.pathEncodable = pathEncodable
        self.bodyEncodable = bodyEncodable
        self.additionalHeadersEncodable = additionalHeaders
        self.pathPostfix = pathPostfix
    }
}
