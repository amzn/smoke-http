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
//  BodyHTTPRequestInput.swift
//  SmokeHTTPClient
//

import Foundation

/**
 HTTP Request Input that only has a body.
 */
public struct BodyHTTPRequestInput<BodyType: Encodable>: HTTPRequestInputProtocol {
    public let queryEncodable: BodyType?
    public let pathEncodable: BodyType?
    public let bodyEncodable: BodyType?
    public let additionalHeadersEncodable: BodyType?
    public let pathPostfix: String?

    public init(encodable: BodyType) {
        self.queryEncodable = nil
        self.pathEncodable = nil
        self.bodyEncodable = encodable
        self.additionalHeadersEncodable = nil
        self.pathPostfix = nil
    }
}
