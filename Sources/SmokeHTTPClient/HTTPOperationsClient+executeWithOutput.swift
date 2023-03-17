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
//  HTTPOperationsClient+executeWithOutput.swift
//  SmokeHTTPClient
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient
import Metrics

public extension HTTPOperationsClient {
    
    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - invocationContext: context to use for this invocation.
     - Returns: the response body.
     - Throws: If an error occurred during the request.
     */
    func executeWithOutput<InputType, OutputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws -> OutputType
    where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath,
            invocationReporting: invocationContext.reporting)
        let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
        let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
        
        return try await executeWithOutputWithWrappedInvocationContext(
            endpointOverride: endpointOverride,
            requestComponents: requestComponents,
            httpMethod: httpMethod,
            invocationContext: wrappingInvocationContext)
    }
    
    /**
     Submits a request that will return a response body to this client asynchronously.
     To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
        - Returns: A future that will produce the execution result or failure.
     */
    internal func executeWithOutputWithWrappedInvocationContext<OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            requestComponents: HTTPRequestComponents,
            httpMethod: HTTPMethod,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws
    -> OutputType where OutputType: HTTPResponseOutputProtocol {
        let durationMetricDetails: (Date, Metrics.Timer?, OutwardsRequestAggregator?)?
        
        if invocationContext.reporting.outwardsRequestAggregator != nil ||
                invocationContext.reporting.latencyTimer != nil {
            durationMetricDetails = (Date(), invocationContext.reporting.latencyTimer, invocationContext.reporting.outwardsRequestAggregator)
        } else {
            durationMetricDetails = nil
        }

        let requestDelegate = clientDelegate
        
        let output: OutputType
        do {
            let response = try await execute(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                invocationContext: invocationContext)
            
            do {
                // decode the provided body into the desired type
                output = try requestDelegate.decodeOutput(
                    output: response.body,
                    headers: response.headers,
                    invocationReporting: invocationContext.reporting)
                
                // report success metric
                invocationContext.reporting.successCounter?.increment()
            } catch {
                // if there was a decoding error, complete with that error
                throw HTTPClientError(responseCode: 400, cause: error)
            }
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
        
        return output
    }
}

#endif
