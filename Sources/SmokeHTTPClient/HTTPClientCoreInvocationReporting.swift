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
//  HTTPClientCoreInvocationReporting.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import NIO

public protocol OutputRequestRecord {
    var requestLatency: TimeInterval { get }
}

public protocol RetriableOutputRequestRecord {
    var outputRequests: [OutputRequestRecord] { get }
}

public protocol RetryAttemptRecord {
    var retryWait: TimeInterval { get }
}

/**
  Provide the ability to record the info about the outward requests for a particular invocation reporting instance.
 
  This is really a stop-gap measure until distributed tracing comes along and we can do this in a more standardised way.
 */
public protocol OutwardsRequestAggregator {
    
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord, onCompletion: @escaping () -> ())
        
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord, onCompletion: @escaping () -> ())
        
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord, onCompletion: @escaping () -> ())
    
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord)
        
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord)
        
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord)
}

public extension OutwardsRequestAggregator {
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord, onCompletion: @escaping () -> ()) {
        recordOutwardsRequest(outputRequestRecord: outputRequestRecord)
        
        onCompletion()
    }
        
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord, onCompletion: @escaping () -> ()) {
        recordRetryAttempt(retryAttemptRecord: retryAttemptRecord)
        
        onCompletion()
    }
       
    @available(swift, deprecated: 2.0, message: "Not thread-safe")
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord, onCompletion: @escaping () -> ()) {
        recordRetriableOutwardsRequest(retriableOutwardsRequest: retriableOutwardsRequest)
        
        onCompletion()
    }
}

/**
 A context related to reporting on the invocation of the HTTPClient. This represents the
 core requirements for invocation reporting.
 
 The HTTPClientCoreInvocationReporting protocol can exposed by higher level clients that manage the
 metrics requirements of the HTTPClientInvocationReporting protocol.
 */
public protocol HTTPClientCoreInvocationReporting {
    associatedtype TraceContextType: InvocationTraceContext
    
    /// The `Logging.Logger` to use for logging for this invocation.
    var logger: Logging.Logger { get }
    
    /// The internal Request Id associated with this invocation.
    var internalRequestId: String { get }
    
    /// The trace context associated with this invocation.
    var traceContext: TraceContextType { get }
    
    var eventLoop: EventLoop? { get }
    
    var outwardsRequestAggregator: OutwardsRequestAggregator? { get }
}

public extension HTTPClientCoreInvocationReporting {
    // The attribute is being added as a non-breaking change, so add a default implementation that replicates existing behaviour
    var eventLoop: EventLoop? {
        return nil
    }
    
    // The attribute is being added as a non-breaking change, so add a default implementation that replicates existing behaviour
    var outwardsRequestAggregator: OutwardsRequestAggregator? {
        return nil
    }
}
