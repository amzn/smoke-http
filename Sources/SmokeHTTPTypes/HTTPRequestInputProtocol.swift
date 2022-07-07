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
//  HTTPRequestInputProtocol.swift
//  SmokeHTTPTypes
//

import Foundation

/**
 A protocol that represents input to a HTTP request.
 */
public protocol HTTPRequestInputProtocol {
    associatedtype QueryType: Encodable
    associatedtype PathType: Encodable
    associatedtype BodyType: Encodable
    associatedtype AdditionalHeadersType: Encodable

    /// An instance of a type that is encodable to a query string
    var queryEncodable: QueryType? { get }
    /// An instance of a type that is encodable to a path
    var pathEncodable: PathType? { get }
    /// An instance of a type that is encodable to a body
    var bodyEncodable: BodyType? { get }
    /// An instance of a type that is encodable to additional headers
    var additionalHeadersEncodable: AdditionalHeadersType? { get }
    /// If there is a specific path postfix
    var pathPostfix: String? { get }
}
