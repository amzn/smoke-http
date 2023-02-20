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
//  MockInvocationTraceContext.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import ClientRuntime

public struct MockInvocationTraceContext: InvocationTraceContext {
    public typealias OutwardsRequestContext = String
    
    public let outwardsRequestContext = "OutwardsRequestContext"
    
    public init() {
        
    }
    
    public func handleOutwardsRequestStart(method: HttpMethodType, uri: Endpoint, logger: Logger, internalRequestId: String,
                                    headers: inout Headers, bodyData: Data) -> String {
        return self.outwardsRequestContext
    }
    
    public func handleOutwardsRequestSuccess(outwardsRequestContext: String?, logger: Logger,
                                             internalRequestId: String,
                                             response: HttpResponse, bodyData: Data?) {
        // do nothing
    }
    
    public func handleOutwardsRequestFailure(outwardsRequestContext: String?, logger: Logger,
                                             internalRequestId: String,
                                             response: HttpResponse?, bodyData: Data?,
                                             error: Error) {
        // do nothing
    }
}
