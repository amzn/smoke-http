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
//  HTTPClientInvocationReporting.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import Metrics

/**
 A context related to reporting on the invocation of the HTTPClient.
 */
public protocol HTTPClientInvocationReporting {
    
    /// The `Logging.Logger` to use for logging for this invocation.
    var logger: Logging.Logger { get }
    
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
