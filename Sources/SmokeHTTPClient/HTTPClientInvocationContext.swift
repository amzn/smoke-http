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
//  HTTPClientInvocationContext.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import Metrics

/**
 A context related to the invocation of the HTTPClient.
 */
public struct HTTPClientInvocationContext {
    public let reporting: HTTPClientInvocationReporting
    public let handlerDelegate: HTTPClientChannelInboundHandlerDelegate
    
    public init(reporting: HTTPClientInvocationReporting,
                handlerDelegate: HTTPClientChannelInboundHandlerDelegate) {
        self.reporting = reporting
        self.handlerDelegate = handlerDelegate
    }
}
