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
//  HTTPResponseComponents.swift
//  SmokeHTTPClient
//

import Foundation

/// The parsed components that specify a request.
public struct HTTPResponseComponents {
    /// any response headers.
    public let headers: [(String, String)]
    /// The body data of the response.
    public let body: Data?

    public init(headers: [(String, String)], body: Data?) {
        self.headers = headers
        self.body = body
    }
}
