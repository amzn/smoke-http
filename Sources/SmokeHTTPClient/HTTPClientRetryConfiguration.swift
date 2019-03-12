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
//  HTTPClientRetryConfiguration.swift
//  SmokeHTTPClient
//

import Foundation

/// Type alias for a retry interval.
public typealias RetryInterval = UInt32

/**
 Retry configuration for the requests made by a HTTPClient.
 */
public struct HTTPClientRetryConfiguration {
    // Number of retries to be attempted
    public let numRetries: Int
    // First interval of retry in millis
    public let baseRetryInterval: RetryInterval
    // Max amount of cumulative time to attempt retries in millis
    public let maxRetryInterval: RetryInterval
    // Exponential backoff for each retry
    public let exponentialBackoff: Double
    // Ramdomized backoff
    public let jitter: Bool
 
    /**
     Initializer.
 
     - Parameters:
         - numRetries: number of retries to be attempted.
         - baseRetryInterval: first interval of retry in millis.
         - maxRetryInterval: max amount of cumulative time to attempt retries in millis
         - exponentialBackoff: exponential backoff for each retry
         - jitter: ramdomized backoff
     */
    public init(numRetries: Int, baseRetryInterval: RetryInterval, maxRetryInterval: RetryInterval,
                exponentialBackoff: Double, jitter: Bool = true) {
        self.numRetries = numRetries
        self.baseRetryInterval = baseRetryInterval
        self.maxRetryInterval = maxRetryInterval
        self.exponentialBackoff = exponentialBackoff
        self.jitter = jitter
    }
    
    public func getRetryInterval(retriesRemaining: Int) -> RetryInterval {
        let base = Double(baseRetryInterval) * Double(numRetries - retriesRemaining)
        let msInterval = RetryInterval(pow(base, exponentialBackoff))
        let boundedMsInterval = min(maxRetryInterval, msInterval)
        
        if jitter {
            #if swift(>=4.2)
                if boundedMsInterval > 0 {
                        return RetryInterval.random(in: 0 ..< boundedMsInterval)
                } else {
                    return 0
                }
            #else
                #if os(Linux)
                    return RetryInterval(random() % Int(boundedMsInterval))
                #else
                    return arc4random_uniform(boundedMsInterval)
                #endif
            #endif
        }
        
        return boundedMsInterval
    }
 
    /// Default try configuration with 5 retries starting at 500 ms interval.
    public static var `default` = HTTPClientRetryConfiguration(numRetries: 5, baseRetryInterval: 500,
                                                               maxRetryInterval: 10000, exponentialBackoff: 2)
 
    /// Retry Configuration with no retries.
    public static var noRetries = HTTPClientRetryConfiguration(numRetries: 0, baseRetryInterval: 0,
                                                               maxRetryInterval: 0, exponentialBackoff: 0)
}
