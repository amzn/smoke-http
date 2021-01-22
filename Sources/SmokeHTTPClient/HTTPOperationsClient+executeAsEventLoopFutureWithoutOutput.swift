// Copyright 2018-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPOperationsClient+executeAsEventLoopFutureWithoutOutput.swift
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

public extension EventLoopFuture where Value == Void {
    func complete<ErrorType: Error>(on completion: @escaping (Swift.Error?) -> (),
                                    typedErrorProvider: @escaping (Swift.Error) -> ErrorType){
        self.whenComplete { result in
            switch result {
            case .success:
                completion(nil)
            case .failure(let error):
                completion(typedErrorProvider(error))
            }
        }
    }
}

public extension HTTPOperationsClient {
    
    /**
     Submits a request that will not return a response body to this client asynchronously as an EventLoopFuture.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - completion: Completion handler called with an error if one occurs or nil otherwise.
        - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
        - invocationContext: context to use for this invocation.
     - Returns: A future that will produce the execution result or failure.
     */
    func executeAsEventLoopFutureWithoutOutput<InputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> EventLoopFuture<Void>
        where InputType: HTTPRequestInputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
            
            return executeAsEventLoopFutureWithoutOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                invocationContext: wrappingInvocationContext)
    }
    
    /**
     Submits a request that will not return a response body to this client asynchronously as an EventLoopFuture.
     To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.
     
     - Parameters:
        - endpointPath: The endpoint path for this request.
        - httpMethod: The http method to use for this request.
        - input: the input body data to send with this request.
        - invocationContext: context to use for this invocation.
     - Returns: A future that will produce a Void result or failure.
     */
    internal func executeAsEventLoopFutureWithoutOutputWithWrappedInvocationContext<InputType,
            InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
        endpointOverride: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        input: InputType,
        invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> EventLoopFuture<Void>
        where InputType: HTTPRequestInputProtocol {
            
            let latencyMetricDetails: (Date, Metrics.Timer)?
            if let latencyTimer = invocationContext.reporting.latencyTimer {
                latencyMetricDetails = (Date(), latencyTimer)
            } else {
                latencyMetricDetails = nil
            }
        
            // submit the asynchronous request
            let future = executeAsEventLoopFuture(endpointOverride: endpointOverride,
                                                  endpointPath: endpointPath,
                                                  httpMethod: httpMethod,
                                                  input: input,
                                                  invocationContext: invocationContext)
                .map { _ -> Void in
                    invocationContext.reporting.successCounter?.increment()
                } .flatMapErrorThrowing { error in
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
            
            future.whenComplete { _ in
                if let durationMetricDetails = latencyMetricDetails {
                    durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
                }
            }
            
            return future
    }
}
