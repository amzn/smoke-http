//
//  RetriableOutwardsRequestAggregator.swift
//

import Foundation

/**
  An internal type conforming to the `OutwardsRequestAggregator` protocol that is used to aggregate
  the outputRequest records for the same output request that is optentially retried.
 */
internal class RetriableOutwardsRequestAggregator:  OutwardsRequestAggregator {
    private(set) var outputRequestRecords: [OutputRequestRecord]
    
    init() {
        self.outputRequestRecords = []
    }
    
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord) {
        self.outputRequestRecords.append(outputRequestRecord)
    }
    
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord) {
        // for this internal type, we don't need to record retry attempts
    }
    
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord) {
        self.outputRequestRecords.append(contentsOf: retriableOutwardsRequest.outputRequests)
    }
}

struct StandardOutputRequestRecord: OutputRequestRecord {
    let requestLatency: TimeInterval
}

struct StandardRetryAttemptRecord: RetryAttemptRecord {
    let retryWait: TimeInterval
}

struct StandardRetriableOutputRequestRecord: RetriableOutputRequestRecord {
    var outputRequests: [OutputRequestRecord]
}
