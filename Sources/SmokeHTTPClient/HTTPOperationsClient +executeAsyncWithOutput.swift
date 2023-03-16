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
//  HTTPOperationsClient+executeAsyncWithOutput.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient
import NIOSSL
import NIOTLS
import Logging
import Metrics

public extension HTTPOperationsClient {
    /**
     Submits a request that will return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.

     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with the response body or any error.
        - invocationContext: context to use for this invocation.
     */
    func executeAsyncWithOutput<InputType, OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String? = nil,
            input: InputType,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
        where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
            return try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<Result<OutputType, HTTPClientError>>(),
                invocationContext: invocationContext)
    }
    
    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
     */
    func executeAsyncWithOutput<InputType, OutputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String? = nil,
            input: InputType,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
    where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Result<OutputType, HTTPClientError>,
        OutputType: HTTPResponseOutputProtocol {
            let requestComponents = try clientDelegate.encodeInputAndQueryString(
                input: input,
                httpPath: endpointPath,
                invocationReporting: invocationContext.reporting)
            let endpoint = getEndpoint(endpointOverride: endpointOverride, path: requestComponents.pathWithQuery)
            let wrappingInvocationContext = invocationContext.withOutgoingDecoratedLogger(endpoint: endpoint, outgoingOperation: operation)
            
            return try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                completion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: wrappingInvocationContext)
    }

    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
         - requestComponents: The request components for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
     */
    internal func executeAsyncWithOutput<OutputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            requestComponents: HTTPRequestComponents,
            httpMethod: HTTPMethod,
            operation: String? = nil,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
    where InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Result<OutputType, HTTPClientError>,
        OutputType: HTTPResponseOutputProtocol {            
            return try executeAsyncWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                requestComponents: requestComponents,
                httpMethod: httpMethod,
                completion: completion,
                asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
                invocationContext: invocationContext)
    }

    /**
     Submits a request that will return a response body to this client asynchronously. To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
     */
    internal func executeAsyncWithOutputWithWrappedInvocationContext<OutputType, InvocationStrategyType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            requestComponents: HTTPRequestComponents,
            httpMethod: HTTPMethod,
            completion: @escaping (Result<OutputType, HTTPClientError>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
            where InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == Result<OutputType, HTTPClientError>,
        OutputType: HTTPResponseOutputProtocol {
            
        let durationMetricDetails: (Date, Metrics.Timer?, OutwardsRequestAggregator?)?
        
        if invocationContext.reporting.outwardsRequestAggregator != nil ||
                invocationContext.reporting.latencyTimer != nil {
            durationMetricDetails = (Date(), invocationContext.reporting.latencyTimer, invocationContext.reporting.outwardsRequestAggregator)
        } else {
            durationMetricDetails = nil
        }

        let requestDelegate = clientDelegate
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        // that will decode the returned body into the desired decodable type.
        let wrappingCompletion: (Result<HTTPResponseComponents, HTTPClientError>) -> () = { (rawResult) in
            let result: Result<OutputType, HTTPClientError>

            switch rawResult {
            case .failure(let error):
                // its an error; complete with the provided error
                result = .failure(error)
                
                // report failure metric
                switch error.category {
                case .clientError:
                    invocationContext.reporting.failure4XXCounter?.increment()
                case .serverError:
                    invocationContext.reporting.failure5XXCounter?.increment()
                }
            case .success(let response):
                do {
                    // decode the provided body into the desired type
                    let output: OutputType = try requestDelegate.decodeOutput(
                        output: response.body,
                        headers: response.headers,
                        invocationReporting: invocationContext.reporting)

                    // complete with the decoded type
                    result = .success(output)
                    
                    // report success metric
                    invocationContext.reporting.successCounter?.increment()
                } catch {
                    // if there was a decoding error, complete with that error
                    result = .failure(HTTPClientError(responseCode: 400, cause: error))
                    
                    // report success metric
                    invocationContext.reporting.failure4XXCounter?.increment()
                }
            }
            
            if let durationMetricDetails = durationMetricDetails {
                let timeInterval = Date().timeIntervalSince(durationMetricDetails.0)
                
                if let latencyTimer = durationMetricDetails.1 {
                    latencyTimer.recordMilliseconds(timeInterval.milliseconds)
                }
                
                if let outwardsRequestAggregator = durationMetricDetails.2 {
                    outwardsRequestAggregator.recordOutwardsRequest(
                        outputRequestRecord: StandardOutputRequestRecord(requestLatency: timeInterval),
                        onCompletion: { asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion) } )
                    
                    return
                }
            }

            asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
        }

        // submit the asynchronous request
        return try executeAsync(endpointOverride: endpointOverride,
                                requestComponents: requestComponents,
                                httpMethod: httpMethod,
                                completion: wrappingCompletion,
                                invocationContext: invocationContext)
    }
}
