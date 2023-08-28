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
//  HTTPError.swift
//  SmokeHTTPClient
//

import Foundation
import NIOHTTP1

/**
 Errors that can be thrown as part of the SmokeHTTPClient library.

 For more nuanced errors specific to a use-case, provide an extension off this enum.
 */
public enum HTTPError: Error {
    // 3xx
    case movedPermanently(location: String)

    // 4xx
    case badRequest(String)
    case badResponse(String)
    case unauthorized(String)

    // 5xx
    case connectionError(String)
    case internalServerError(String)
    case invalidRequest(String)

    // Other
    case validationError(reason: String)
    case deserializationError(cause: Swift.Error)
    case unknownError(String)
}
