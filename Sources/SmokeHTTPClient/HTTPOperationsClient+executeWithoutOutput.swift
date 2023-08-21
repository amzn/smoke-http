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
//  HTTPOperationsClient+executeWithoutOutput.swift
//  SmokeHTTPClient
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import Foundation
import NIO
import NIOHTTP1
import Metrics

public extension HTTPOperationsClient {
    
    /**
     Submits a request that will not return a response body to this client asynchronously.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - clientName: Optionally the name of the client to use for reporting.
        - operation: Optionally the name of the operation to use for reporting.
        - input: the input body data to send with this request.
        - completion: Completion handler called with an error if one occurs or nil otherwise.
        - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
        - invocationContext: context to use for this invocation.
     - Throws: If an error occurred during the request.
     */
    func executeWithoutOutput<InputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        clientName: String? = nil,
        operation: String? = nil,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws
    where InputType: HTTPRequestInputProtocol {
        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath,
            invocationReporting: invocationContext.reporting)
        let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
        let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
        
        let clientNameToUse = clientName ?? "UnnamedClient"
        let operationToUse = operation ?? "UnnamedOperation"
        let spanName = "\(clientNameToUse).\(operationToUse)"
        
        return try await withSpanIfEnabled(spanName) { _ in
            return try await executeWithoutOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                invocationContext: wrappingInvocationContext)
        }
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously.
     To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
     - Returns: A future that will produce a Void result or failure.
     */
    internal func executeWithoutOutputWithWrappedInvocationContext<
            InvocationReportingType: HTTPClientInvocationReporting,
            HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        requestComponents: HTTPRequestComponents,
        httpMethod: HTTPMethod,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws {
        
            let durationMetricDetails: (Date, Metrics.Timer?, OutwardsRequestAggregator?)?
            
            if invocationContext.reporting.outwardsRequestAggregator != nil ||
                invocationContext.reporting.latencyTimer != nil {
                durationMetricDetails = (Date(), invocationContext.reporting.latencyTimer, invocationContext.reporting.outwardsRequestAggregator)
            } else {
                durationMetricDetails = nil
            }
            
            // submit the asynchronous request
            do {
                _ = try await execute(endpointOverride: endpointOverride,
                                    requestComponents: requestComponents,
                                    httpMethod: httpMethod,
                                    invocationContext: invocationContext)
            } catch {
                if let typedError = error as? HTTPClientError {
                    // report failure metric
                    switch typedError.category {
                    case .clientError:
                        invocationContext.reporting.failure4XXCounter?.increment()
                    case .serverError:
                        invocationContext.reporting.failure5XXCounter?.increment()
                    }
                }
                
                // rethrow the error
                throw error
            }
            
            invocationContext.reporting.successCounter?.increment()
            
            if let durationMetricDetails = durationMetricDetails {
                let timeInterval = Date().timeIntervalSince(durationMetricDetails.0)
                
                if let latencyTimer = durationMetricDetails.1 {
                    latencyTimer.recordMilliseconds(timeInterval.milliseconds)
                }
                
                if let outwardsRequestAggregator = durationMetricDetails.2 {
                    await outwardsRequestAggregator.recordOutwardsRequest(
                        outputRequestRecord: StandardOutputRequestRecord(requestLatency: timeInterval))
                }
            }
    }
}

#endif
