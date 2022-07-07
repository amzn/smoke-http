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
//  HTTPResponseInputProtocol.swift
//  SmokeHTTPTypes
//

import Foundation

/**
 A protocol that represents output from a HTTP response.
 */
public protocol HTTPResponseOutputProtocol {
    associatedtype BodyType: Decodable
    associatedtype HeadersType: Decodable
    
    /**
     Composes an instance from its constituent Decodable parts.
     May return one of its constituent parts if of a compatible type.
 
     - Parameters:
        - bodyDecodableProvider: provider for the decoded body for this instance.
        - headersDecodableProvider: provider for the decoded headers for this instance.
     */
    static func compose(bodyDecodableProvider: () throws -> BodyType,
                        headersDecodableProvider: () throws -> HeadersType) throws -> Self
}
