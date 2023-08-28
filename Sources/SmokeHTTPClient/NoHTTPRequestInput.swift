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
//  NoHTTPRequestInput.swift
//  SmokeHTTPClient
//

import Foundation

/**
 HTTP Request Input has no input.
 */
public struct NoHTTPRequestInput: HTTPRequestInputProtocol {
    public let queryEncodable: String?
    public let pathEncodable: String?
    public let bodyEncodable: String?
    public let additionalHeadersEncodable: String?
    public let pathPostfix: String?

    public init() {
        self.queryEncodable = nil
        self.pathEncodable = nil
        self.bodyEncodable = nil
        self.additionalHeadersEncodable = nil
        self.pathPostfix = nil
    }
}
