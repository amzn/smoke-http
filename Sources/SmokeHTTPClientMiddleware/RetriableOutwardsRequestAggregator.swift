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
//  RetriableOutwardsRequestAggregator.swift
//  SmokeHTTPTypes
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)
import Foundation
import HttpMiddleware
import StandardHttpClientMiddleware

public actor RetriableOutwardsRequestAggregator {
    public private(set) var retriableOutputRequestRecords: [RetriableOutputRequestRecord]
    
    @TaskLocal
    public static var aggregator: RetriableOutwardsRequestAggregator?
    
    public init() {
        self.retriableOutputRequestRecords = []
    }
    
    public func record(retriableOutputRequestRecord: RetriableOutputRequestRecord) {
        self.retriableOutputRequestRecords.append(retriableOutputRequestRecord)
    }
}

public struct OutputRequestRecord: _MiddlewareSendable {
    public let requestLatency: Int
    
    public init(requestLatency: Int) {
        self.requestLatency = requestLatency
    }
}

public struct RetryAttemptRecord: _MiddlewareSendable {
    public let retryWait: RetryInterval
    
    public init(retryWait: RetryInterval) {
        self.retryWait = retryWait
    }
}

public struct RetriableOutputRequestRecord: _MiddlewareSendable {
    public let requestTags: [String]
    public let outputRequests: [(RetryAttemptRecord?, OutputRequestRecord)]
    
    public init(requestTags: [String],
                outputRequests: [(RetryAttemptRecord?, OutputRequestRecord)]) {
        self.requestTags = requestTags
        self.outputRequests = outputRequests
    }
}
#endif
