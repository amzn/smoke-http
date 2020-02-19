// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  AsyncResponseInvocationStrategy.swift
//  SmokeHTTPClient
//

import Foundation

/**
 A strategy protocol that manages how to invocate the asynchronous completion handler
 for response from the HTTPClient.
 */
public protocol AsyncResponseInvocationStrategy {
    associatedtype OutputType

    /**
     Function to handle the invocation of the response completion handler given
     the specified response.

     - Parameters:
        - response: The Result to invocate the completion handler with.
        - completion: The completion handler to invocate.
     */
    func invokeResponse(response: OutputType,
                        completion: @escaping (OutputType) -> ())
}
