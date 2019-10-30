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
//  StandardHTTPClientInvocationReporting.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import Metrics

public struct StandardHTTPClientInvocationReporting: HTTPClientInvocationReporting {
    public let logger: Logging.Logger
    public let successCounter: Metrics.Counter?
    public let failure5XXCounter: Metrics.Counter?
    public let failure4XXCounter: Metrics.Counter?
    public let retryCountRecorder: Metrics.Recorder?
    public let latencyTimer: Metrics.Timer?
    
    public init(logger: Logging.Logger = Logger(label: "com.amazon.SmokeHTTP.SmokeHTTPClient.StandardHTTPClientInvocationReporting"),
                successCounter: Metrics.Counter? = nil,
                failure5XXCounter: Metrics.Counter? = nil,
                failure4XXCounter: Metrics.Counter? = nil,
                retryCountRecorder: Metrics.Recorder? = nil,
                latencyTimer: Metrics.Timer? = nil) {
        self.logger = logger
        self.successCounter = successCounter
        self.failure5XXCounter = failure5XXCounter
        self.failure4XXCounter = failure4XXCounter
        self.retryCountRecorder = retryCountRecorder
        self.latencyTimer = latencyTimer
    }
}
