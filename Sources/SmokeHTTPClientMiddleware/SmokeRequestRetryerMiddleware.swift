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
//  SmokeRequestRetryerMiddleware.swift
//  SmokeHTTPClientMiddleware
//

import HttpMiddleware
import HttpClientMiddleware
import StandardHttpClientMiddleware
import SmokeHTTPTypes
import Foundation
import Metrics

private let timeIntervalToMilliseconds: Double = 1000

private struct OutputRequestRecordStatus {
    let aggregator: RetriableOutwardsRequestAggregator
    var outputRequests: [(RetryAttemptRecord?, OutputRequestRecord)]
    
    func withRetryAttempt(retryWait: RetryInterval?, retryStart: Date) -> Self {
        let retryAttemptRecord: RetryAttemptRecord?
        if let retryWait = retryWait {
            retryAttemptRecord = RetryAttemptRecord(retryWait: retryWait)
        } else {
            retryAttemptRecord = nil
        }
        
        let attemptLatency = Date().timeIntervalSince(retryStart).milliseconds
        
        var updated = self
        updated.outputRequests.append((retryAttemptRecord, OutputRequestRecord(requestLatency: attemptLatency)))
        
        return updated
    }
}

public typealias HTTPClientRetryConfiguration = StandardHttpClientMiddleware.HTTPClientRetryConfiguration

public struct SmokeRequestRetryerMiddleware<HTTPRequestType: HttpClientRequestProtocol,
                                            HTTPResponseType: HttpClientResponseProtocol>: RequestRetryerMiddlewareProtocol {
    public typealias InputType = HTTPRequestType
    public typealias OutputType = HTTPResponseType
    
    private let retryConfiguration: HTTPClientRetryConfiguration
    private let errorStatusFunction: (Swift.Error) -> (isRetriable: Bool, code: UInt)
    private let invocationMetrics: HTTPClientInvocationMetrics?
    private let requestTags: [String]
    
    public init(retryConfiguration: HTTPClientRetryConfiguration,
                errorStatusFunction: @escaping (Swift.Error) -> (isRetriable: Bool, code: UInt),
                invocationMetrics: HTTPClientInvocationMetrics?,
                requestTags: [String]) {
        self.retryConfiguration = retryConfiguration
        self.errorStatusFunction = errorStatusFunction
        self.invocationMetrics = invocationMetrics
        self.requestTags = requestTags
    }
    
    public func handle<HandlerType>(input: HTTPRequestType,
                                    context: MiddlewareContext, next: HandlerType) async throws
    -> HTTPResponseType
    where HandlerType : MiddlewareHandlerProtocol, HTTPRequestType == HandlerType.InputType,
    HTTPResponseType == HandlerType.OutputType {
        let latencyMetricDetails: (Date, Metrics.Timer)?
        if let latencyTimer = self.invocationMetrics?.latencyTimer {
            latencyMetricDetails = (Date(), latencyTimer)
        } else {
            latencyMetricDetails = nil
        }
        
        let outputRequestRecordStatus: OutputRequestRecordStatus?
        if let aggregator = RetriableOutwardsRequestAggregator.aggregator {
            outputRequestRecordStatus = OutputRequestRecordStatus(aggregator: aggregator,
                                                                  outputRequests: [])
        } else {
            outputRequestRecordStatus = nil
        }
        
        return try await handle(input: input, context: context, next: next,
                                retriesRemaining: self.retryConfiguration.numRetries,
                                mostRecent: nil,
                                overallLatencyMetricDetails: latencyMetricDetails,
                                outputRequestRecordStatus: outputRequestRecordStatus)
    }
    
    private func handle<HandlerType>(input: HTTPRequestType, context: MiddlewareContext, next: HandlerType,
                                     retriesRemaining: Int,
                                     mostRecent: (result: RequestRetryerResult<HTTPResponseType>, wait: RetryInterval)?,
                                     overallLatencyMetricDetails: (Date, Metrics.Timer)?,
                                     outputRequestRecordStatus: OutputRequestRecordStatus?) async throws
    -> HTTPResponseType
    where HandlerType : MiddlewareHandlerProtocol, HTTPRequestType == HandlerType.InputType,
    HTTPResponseType == HandlerType.OutputType {
        if let mostRecent = mostRecent {
            guard retriesRemaining > 0 else {
                await handleCompletion(result: mostRecent.result, retriesRemaining: retriesRemaining,
                                       overallLatencyMetricDetails: overallLatencyMetricDetails,
                                       outputRequestRecordStatus: outputRequestRecordStatus)
                
                throw RequestRetryerError.maximumRetryAttemptsExceeded(attemptCount: self.retryConfiguration.numRetries,
                                                                       mostRecentResult: mostRecent.result)
            }
        }
        
        let attemptLatencyMetricDetails: (Date, outputRequestRecordStatus: OutputRequestRecordStatus)?
        if let outputRequestRecordStatus = outputRequestRecordStatus {
            attemptLatencyMetricDetails = (Date(), outputRequestRecordStatus)
        } else {
            attemptLatencyMetricDetails = nil
        }
        
        do {
            let response = try await next.handle(input: input, context: context)
            let result: RequestRetryerResult<HTTPResponseType> = .response(response)
            
            let updatedOutputRequestRecordStatus: OutputRequestRecordStatus?
            if let attemptLatencyMetricDetails = attemptLatencyMetricDetails {
                updatedOutputRequestRecordStatus =
                    attemptLatencyMetricDetails.outputRequestRecordStatus.withRetryAttempt(retryWait: mostRecent?.wait,
                                                                                           retryStart: attemptLatencyMetricDetails.0)
            } else {
                updatedOutputRequestRecordStatus = nil
            }
                        
            switch response.statusCode {
            case 500...599:
                let retryInterval = try await self.retryConfiguration.waitForNextRetry(retriesRemaining: retriesRemaining)
                
                // server error, retry
                return try await handle(input: input, context: context, next: next, retriesRemaining: retriesRemaining - 1,
                                        mostRecent: (result, retryInterval),
                                        overallLatencyMetricDetails: overallLatencyMetricDetails,
                                        outputRequestRecordStatus: updatedOutputRequestRecordStatus)
            default:
                await handleCompletion(result: result, retriesRemaining: retriesRemaining,
                                       overallLatencyMetricDetails: overallLatencyMetricDetails,
                                       outputRequestRecordStatus: updatedOutputRequestRecordStatus)
                
                return response
            }
        } catch {
            let status = self.errorStatusFunction(error)
            let result: RequestRetryerResult<HTTPResponseType> = .error(cause: error, code: status.code)
            
            let updatedOutputRequestRecordStatus: OutputRequestRecordStatus?
            if let attemptLatencyMetricDetails = attemptLatencyMetricDetails {
                updatedOutputRequestRecordStatus =
                    attemptLatencyMetricDetails.outputRequestRecordStatus.withRetryAttempt(retryWait: mostRecent?.wait,
                                                                                           retryStart: attemptLatencyMetricDetails.0)
            } else {
                updatedOutputRequestRecordStatus = nil
            }
            
            if status.isRetriable {
                let retryInterval = try await self.retryConfiguration.waitForNextRetry(retriesRemaining: retriesRemaining)
                
                return try await handle(input: input, context: context, next: next, retriesRemaining: retriesRemaining - 1,
                                        mostRecent: (result, retryInterval),
                                        overallLatencyMetricDetails: overallLatencyMetricDetails,
                                        outputRequestRecordStatus: updatedOutputRequestRecordStatus)
            }
            
            await handleCompletion(result: result, retriesRemaining: retriesRemaining,
                                   overallLatencyMetricDetails: overallLatencyMetricDetails,
                                   outputRequestRecordStatus: updatedOutputRequestRecordStatus)
            
            // rethrow error
            throw error
        }
    }
    
    private func handleCompletion(result: RequestRetryerResult<HTTPResponseType>,
                                  retriesRemaining: Int,
                                  overallLatencyMetricDetails: (Date, Metrics.Timer)?,
                                  outputRequestRecordStatus: OutputRequestRecordStatus?) async {
        switch result {
        case .response(let response):
            handleCompletion(statusCode: response.statusCode)
        case .error(_, let statusCode):
            handleCompletion(statusCode: statusCode)
        }
        
        // report the retryCount metric
        let retryCount = self.retryConfiguration.numRetries - retriesRemaining
        self.invocationMetrics?.retryCountRecorder?.record(retryCount)
        
        if let overallLatencyMetricDetails = overallLatencyMetricDetails {
            overallLatencyMetricDetails.1.recordMilliseconds(Date().timeIntervalSince(overallLatencyMetricDetails.0).milliseconds)
        }
        
        if let outputRequestRecordStatus = outputRequestRecordStatus {
            let retriableOutputRequestRecord = RetriableOutputRequestRecord(requestTags: self.requestTags,
                                                                            outputRequests: outputRequestRecordStatus.outputRequests)
            
            await outputRequestRecordStatus.aggregator.record(retriableOutputRequestRecord: retriableOutputRequestRecord)
        }
    }
    
    private func handleCompletion(statusCode: UInt) {
        switch statusCode {
        case 200...299:
            self.invocationMetrics?.successCounter?.increment()
        case 400...499:
            self.invocationMetrics?.failure4XXCounter?.increment()
        case 500...599:
            self.invocationMetrics?.failure5XXCounter?.increment()
        default:
            // nothing to do
            break
        }
    }
}

internal extension TimeInterval {
    var milliseconds: Int {
        return Int(self * timeIntervalToMilliseconds)
    }
}
