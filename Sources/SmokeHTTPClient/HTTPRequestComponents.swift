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
//  HTTPRequestComponents.swift
//  SmokeHTTPClient
//

import Foundation

/// The parsed components that specify a request.
public struct HTTPRequestComponents {
    /// the path for the request.
    public let path: String
    /// the query items for the request.
    public let queryItems: [URLQueryItem]
    /// any request specific headers that needs to be added.
    public let additionalHeaders: [(String, String)]
    /// The body data of the request.
    public let body: Data

    public init(path: String, queryItems: [URLQueryItem], additionalHeaders: [(String, String)], body: Data) {
        self.path = path
        self.queryItems = queryItems
        self.additionalHeaders = additionalHeaders
        self.body = body
    }
}
