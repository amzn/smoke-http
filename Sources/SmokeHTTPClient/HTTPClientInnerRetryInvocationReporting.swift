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
//  HTTPClientInnerRetryInvocationReporting.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import Metrics

/**
 When using retry wrappers, the `HTTPClient` itself shouldn't record any metrics.
 */
internal struct HTTPClientInnerRetryInvocationReporting<TraceContextType: InvocationTraceContext>: HTTPClientInvocationReporting {
    let internalRequestId: String
    let traceContext: TraceContextType
    let logger: Logging.Logger
    let successCounter: Metrics.Counter? = nil
    let failure5XXCounter: Metrics.Counter? = nil
    let failure4XXCounter: Metrics.Counter? = nil
    let retryCountRecorder: Metrics.Recorder? = nil
    let latencyTimer: Metrics.Timer? = nil
}
