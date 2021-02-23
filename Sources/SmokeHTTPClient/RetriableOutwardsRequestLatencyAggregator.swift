//
//  RetriableOutwardsRequestAggregator.swift
//

import Foundation

internal class RetriableOutwardsRequestAggregator:  OutwardsRequestAggregator {
    private(set) var outputRequestRecords: [OutputRequestRecord]
    
    init() {
        self.outputRequestRecords = []
    }
    
    func recordOutwardsRequest(outputRequestRecord: OutputRequestRecord) {
        self.outputRequestRecords.append(outputRequestRecord)
    }
    
    func recordRetriableOutwardsRequest(retriableOutwardsRequest: RetriableOutputRequestRecord) {
        self.outputRequestRecords.append(contentsOf: retriableOutwardsRequest.outputRequests)
    }
}

struct StandardOutputRequestRecord: OutputRequestRecord {
    let requestLatency: TimeInterval
}

struct StandardRetriableOutputRequestRecord: RetriableOutputRequestRecord {
    var outputRequests: [OutputRequestRecord]
}
