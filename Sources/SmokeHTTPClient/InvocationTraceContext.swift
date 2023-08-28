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
//  InvocationTraceContext.swift
//  SmokeHTTPClient
//

import Foundation
import NIOHTTP1
import Logging
import AsyncHTTPClient

public protocol InvocationTraceContext {
    associatedtype OutwardsRequestContext
    
    func handleOutwardsRequestStart(
        method: HTTPMethod, uri: String,
        logger: Logging.Logger, internalRequestId: String,
        headers: inout HTTPHeaders, bodyData: Data) -> OutwardsRequestContext
    
    func handleOutwardsRequestSuccess(
        outwardsRequestContext: OutwardsRequestContext?, logger: Logging.Logger, internalRequestId: String,
        response: HTTPClient.Response, bodyData: Data?)
    
    func handleOutwardsRequestFailure(
        outwardsRequestContext: OutwardsRequestContext?, logger: Logging.Logger, internalRequestId: String, response: HTTPClient.Response?, bodyData: Data?, error: Swift.Error)
}
