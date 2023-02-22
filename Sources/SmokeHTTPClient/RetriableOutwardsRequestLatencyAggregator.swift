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

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)
extension RetriableOutwardsRequestAggregator {
    func records() async -> [OutputRequestRecord] {
        return await withCheckedContinuation { cont in
            withRecords { records in
                cont.resume(returning: records)
            }
        }
    }
}
#endif

public struct StandardOutputRequestRecord: OutputRequestRecord {
    public let requestLatency: TimeInterval
    
    public init(requestLatency: TimeInterval) {
        self.requestLatency = requestLatency
    }
}

public struct StandardRetryAttemptRecord: RetryAttemptRecord {
    public let retryWait: TimeInterval
    
    public init(retryWait: TimeInterval) {
        self.retryWait = retryWait
    }
}

public struct StandardRetriableOutputRequestRecord: RetriableOutputRequestRecord {
    public var outputRequests: [OutputRequestRecord]
    
    public init(outputRequests: [OutputRequestRecord]) {
        self.outputRequests = outputRequests
    }
}
