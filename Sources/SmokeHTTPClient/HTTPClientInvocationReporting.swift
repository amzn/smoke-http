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
//  HTTPClientInvocationReporting.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import Metrics

private let timeIntervalToMilliseconds: Double = 1000

/**
 A context related to the metrics on the invocation of a SmokeAWS operation.
 */
public protocol HTTPClientInvocationMetrics {
    
    /// The `Metrics.Counter` to record the success of this invocation.
    var successCounter: Metrics.Counter? { get }
    
    /// The `Metrics.Counter` to record the failure of this invocation.
    var failure5XXCounter: Metrics.Counter? { get }
    
    /// The `Metrics.Counter` to record the failure of this invocation.
    var failure4XXCounter: Metrics.Counter? { get }
    
    /// The `Metrics.Recorder` to record the number of retries that occurred as part of this invocation.
    var retryCountRecorder: Metrics.Recorder? { get }
    
    /// The `Metrics.Recorder` to record the duration of this invocation.
    var latencyTimer: Metrics.Timer? { get }
}

public struct StandardHTTPClientInvocationMetrics: HTTPClientInvocationMetrics {
    public let successCounter: CoreMetrics.Counter?
    public let failure5XXCounter: CoreMetrics.Counter?
    public let failure4XXCounter: CoreMetrics.Counter?
    public let retryCountRecorder: CoreMetrics.Recorder?
    public let latencyTimer: CoreMetrics.Timer?
    
    public init(successCounter: CoreMetrics.Counter? = nil, failure5XXCounter: CoreMetrics.Counter? = nil,
                failure4XXCounter: CoreMetrics.Counter? = nil, retryCountRecorder: CoreMetrics.Recorder? = nil,
                latencyTimer: CoreMetrics.Timer?) {
        self.successCounter = successCounter
        self.failure5XXCounter = failure5XXCounter
        self.failure4XXCounter = failure4XXCounter
        self.retryCountRecorder = retryCountRecorder
        self.latencyTimer = latencyTimer
    }
}

/**
 A context related to reporting on the invocation of the HTTPClient. This interface extends the
 `HTTPClientCoreInvocationReporting` protocol by adding metrics defined by the `HTTPClientInvocationMetrics` protocol.
 */
public typealias HTTPClientInvocationReporting = HTTPClientInvocationMetrics & HTTPClientCoreInvocationReporting

internal extension TimeInterval {
    var milliseconds: Int {
        return Int(self * timeIntervalToMilliseconds)
    }
}

internal extension Int {
    var millisecondsToTimeInterval: TimeInterval {
        return TimeInterval(self) / timeIntervalToMilliseconds
    }
}
