// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  SDKRetryerMiddleware.swift
//  SmokeHTTPMiddleware
//

import Foundation
import SwiftMiddleware
import ClientRuntime
import SmokeHTTPClient
import Metrics

private let millisecondsToNanoSeconds: UInt64 = 1000000
private let timeIntervalToMilliseconds: Double = 1000

private extension TimeInterval {
    var milliseconds: Int {
        return Int(self * timeIntervalToMilliseconds)
    }
}

private extension Int {
    var millisecondsToTimeInterval: TimeInterval {
        return TimeInterval(self) / timeIntervalToMilliseconds
    }
}

public struct SDKRetryerMiddleware<Context: SmokeMiddlewareContext, ErrorType>: MiddlewareProtocol {
    public typealias Input = SmokeSdkHttpRequestBuilder
    public typealias Output = HttpResponse
        
    let retryer: SDKRetryer
    let retryConfiguration: HTTPClientRetryConfiguration
    let metrics: StandardHTTPClientInvocationMetrics
    let outwardsRequestAggregatorV2: OutwardsRequestAggregatorV2?
    // legacy aggregator; only the boxed/existential will be available
    let outwardsRequestAggregator: OutwardsRequestAggregator?
    
    var requiresAggregation: Bool {
        return outwardsRequestAggregatorV2 != nil || outwardsRequestAggregator != nil
    }

    public init(retryer: SDKRetryer, retryConfiguration: HTTPClientRetryConfiguration,
                metrics: StandardHTTPClientInvocationMetrics, outwardsRequestAggregatorV2: OutwardsRequestAggregatorV2?,
                outwardsRequestAggregator: OutwardsRequestAggregator?) {
        self.retryer = retryer
        self.retryConfiguration = retryConfiguration
        self.metrics = metrics
        self.outwardsRequestAggregatorV2 = outwardsRequestAggregatorV2
        self.outwardsRequestAggregator = outwardsRequestAggregator
    }
    
    internal struct AggregationDetails {
        var requestLatencies: [TimeInterval] = []
        var retryWaits: [TimeInterval] = []
    }
    
    internal struct RetryState {
        var retriesRemaining: Int
        let latencyMetricDetails: (Date, Metrics.Timer)?
        var aggregationDetails: AggregationDetails?
    }
    
    internal struct Attempt {
        let input: SmokeSdkHttpRequestBuilder
        let context: Context
    }
    
    public func handle(_ input: SmokeSdkHttpRequestBuilder, context: Context,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        let latencyMetricDetails: (Date, Metrics.Timer)?
        if let latencyTimer = self.metrics.latencyTimer {
            latencyMetricDetails = (Date(), latencyTimer)
        } else {
            latencyMetricDetails = nil
        }
        
        let attempt = Attempt(input: input, context: context)
        
        let aggregationDetails: AggregationDetails?
        if self.requiresAggregation {
            aggregationDetails = AggregationDetails()
        } else {
            aggregationDetails = nil
        }
        
        let state = RetryState(retriesRemaining: self.retryConfiguration.numRetries,
                               latencyMetricDetails: latencyMetricDetails,
                               aggregationDetails: aggregationDetails)
        
        return try await attemptRequest(attempt: attempt, state: state, next: next)
    }
    
    private func attemptRequest(attempt: Attempt, state: RetryState,
                                next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws -> HttpResponse {
        let attemptStart: Date?
        if state.aggregationDetails != nil  {
            attemptStart = Date()
        } else {
            attemptStart = nil
        }
        
        // submit the asynchronous request
        let result: Swift.Result<HttpResponse, SdkError<ErrorType>>
        do {
            let response = try await next(attempt.input, attempt.context)
            
            result = .success(response)
        } catch let error as SdkError<ErrorType> {
            result = .failure(error)
        }
        
        var updatedState = state
        if let attemptStart = attemptStart {
            updatedState.aggregationDetails?.requestLatencies.append(Date().timeIntervalSince(attemptStart))
        }
        
        switch result {
        case .success(let response):
            await self.onSuccess(attempt: attempt, response: response, state: updatedState)
            
            return response
        case .failure(let failure):
            return try await self.retry(attempt: attempt, dueTo: failure, state: updatedState, next: next)
        }
    }
    
    func onSuccess(attempt: Attempt, response: HttpResponse?, state: RetryState) async {
        // report success metric
        self.metrics.successCounter?.increment()
        
        await onComplete(attempt: attempt, response: response, state: state)
    }
    
    private func retry(attempt: Attempt, dueTo error: SdkError<ErrorType>, state: RetryState,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        let logger = attempt.context.logger

        let shouldRetryOnError = self.retryer.isErrorRetryable(error: error)
        
        // if there are retries remaining and we should retry on this error
        if state.retriesRemaining > 0 && shouldRetryOnError {
            // determine the required interval
            let retryInterval = Int(retryConfiguration.getRetryInterval(retriesRemaining: state.retriesRemaining))
            
            var updatedState = state
            updatedState.retriesRemaining -= 1
            updatedState.aggregationDetails?.retryWaits.append(retryInterval.millisecondsToTimeInterval)
            
            logger.warning(
                "Request failed with error: \(error). Remaining retries: \(state.retriesRemaining). Retrying in \(retryInterval) ms.")
            try await Task.sleep(nanoseconds: UInt64(retryInterval) * millisecondsToNanoSeconds)
            logger.trace("Reattempting request due to remaining retries: \(state.retriesRemaining)")
            
            return try await attemptRequest(attempt: attempt, state: updatedState, next: next)
        }
        
        if !shouldRetryOnError {
            logger.trace("Request not retried due to error returned: \(error)")
        } else {
            logger.trace("Request not retried due to maximum retries: \(retryConfiguration.numRetries)")
        }
        
        // report failure metric
        let errorType = retryer.getErrorType(error: error)
        switch errorType {
        case .clientError:
            self.metrics.failure4XXCounter?.increment()
        case .serverError, .transient, .throttling:
            self.metrics.failure5XXCounter?.increment()
        }
        
        await onComplete(attempt: attempt, response: nil, state: state)

        // its an error; complete with the provided error
        throw error
    }
    
    func onComplete(attempt: Attempt, response: HttpResponse?, state: RetryState) async {
        // report the retryCount metric
        let retryCount = retryConfiguration.numRetries - state.retriesRemaining
        self.metrics.retryCountRecorder?.record(retryCount)
        
        if let (date, timer) = state.latencyMetricDetails {
            timer.recordMilliseconds(Date().timeIntervalSince(date).milliseconds)
        }
        
        if let aggregationDetails = state.aggregationDetails {
            if let outwardsRequestAggregatorV2 = self.outwardsRequestAggregatorV2 {
                let record = OutputRequestRecordV2(host: attempt.input.host,
                                                   responseCode: response?.statusCode.rawValue,
                                                   requestLatencies: aggregationDetails.requestLatencies,
                                                   retryWaits: aggregationDetails.retryWaits)
                
                await outwardsRequestAggregatorV2.addRecord(record)
            }
            
            if let outwardsRequestAggregator = self.outwardsRequestAggregator {
                let records: [OutputRequestRecord] = aggregationDetails.requestLatencies.map { requestLatency in
                    return StandardOutputRequestRecord(requestLatency: requestLatency)
                }
                
                await outwardsRequestAggregator.recordRetriableOutwardsRequest(
                    retriableOutwardsRequest: StandardRetriableOutputRequestRecord(outputRequests: records))
                
                for retryWait in aggregationDetails.retryWaits {
                    let retryAttemptRecord = StandardRetryAttemptRecord(retryWait: retryWait)
                    await outwardsRequestAggregator.recordRetryAttempt(retryAttemptRecord: retryAttemptRecord)
                }
            }
        }
    }
}





// CommonRunTimeError
