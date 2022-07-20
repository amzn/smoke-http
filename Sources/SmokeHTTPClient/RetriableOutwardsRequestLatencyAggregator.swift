//
//  RetriableOutwardsRequestAggregator.swift
//

import Foundation

/**
  An internal type conforming to the `OutwardsRequestAggregator` protocol that is used to aggregate
  the outputRequest records for the same output request that is optentially retried.
 */
internal class RetriableOutwardsRequestAggregator:  OutwardsRequestAggregator {
    private var outputRequestRecords: [OutputRequestRecord]
    
    internal let accessQueue = DispatchQueue(
                label: "com.amazon.SmokeHTTP.RetriableOutwardsRequestAggregator.accessQueue",
                target: DispatchQueue.global())
    
    init() {
        self.outputRequestRecords = []
    }
    
    func withRecords(completion: @escaping ([OutputRequestRecord]) -> ()) {
        self.accessQueue.async {
            completion(self.outputRequestRecords)
        }
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
    
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord, onCompletion: @escaping () -> ()) {
        self.accessQueue.async {
            self.outputRequestRecords.append(outputRequestRecord)
            
            onCompletion()
        }
    }
    
    func recordRetryAttempt(retryAttemptRecord: RetryAttemptRecord, onCompletion: @escaping () -> ()) {
        onCompletion()
    }
    
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord, onCompletion: @escaping () -> ()) {
        self.accessQueue.async {
            self.outputRequestRecords.append(contentsOf: retriableOutwardsRequest.outputRequests)
            
            onCompletion()
        }
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
