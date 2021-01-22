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
//  HTTPOperationsClient+executeAsEventLoopFutureWithOutput.swift
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

public extension EventLoopFuture {
    func complete<ErrorType: Error>(on completion: @escaping (Result<Value, ErrorType>) -> (),
                                    typedErrorProvider: @escaping (Swift.Error) -> ErrorType){
        self.whenComplete { result in
            switch result {
            case .success(let output):
                completion(.success(output))
            case .failure(let error):
                completion(.failure(typedErrorProvider(error)))
            }
        }
    }
}

public extension HTTPOperationsClient {
    
    /**
     Submits a request that will return a response body to this client asynchronously as an EventLoopFuture.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - completion: Completion handler called with the response body or any error.
         - invocationContext: context to use for this invocation.
     - Returns: A future that will produce the execution result or failure.
     */
    func executeAsEventLoopFutureWithOutput<InputType, OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> EventLoopFuture<OutputType>
            where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
            let wrappingInvocationContext = invocationContext.withOutgoingRequestIdLoggerMetadata()
            
            return executeAsEventLoopFutureWithOutputWithWrappedInvocationContext(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                invocationContext: wrappingInvocationContext)
    }

    /**
     Submits a request that will return a response body to this client asynchronously using an EventLoopFuture.
     To be called when the `InvocationContext` has already been wrapped with an outgoingRequestId aware Logger.

     - Parameters:
         - endpointPath: The endpoint path for this request.
         - httpMethod: The http method to use for this request.
         - input: the input body data to send with this request.
         - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
         - invocationContext: context to use for this invocation.
        - Returns: A future that will produce the execution result or failure.
     */
    internal func executeAsEventLoopFutureWithOutputWithWrappedInvocationContext<InputType, OutputType,
        InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> EventLoopFuture<OutputType>
            where InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol {
        let durationMetricDetails: (Date, Metrics.Timer)?
        if let durationTimer = invocationContext.reporting.latencyTimer {
            durationMetricDetails = (Date(), durationTimer)
        } else {
            durationMetricDetails = nil
        }

        let requestDelegate = clientDelegate
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        // that will decode the returned body into the desired decodable type.
        
        let future = executeAsEventLoopFuture(endpointOverride: endpointOverride,
                                              endpointPath: endpointPath, httpMethod: httpMethod,
                                              input: input, invocationContext: invocationContext)
            .flatMapThrowing { (response) -> OutputType in
                do {
                    // decode the provided body into the desired type
                    let output: OutputType = try requestDelegate.decodeOutput(
                        output: response.body,
                        headers: response.headers,
                        invocationReporting: invocationContext.reporting)
                    
                    // report success metric
                    invocationContext.reporting.successCounter?.increment()
                    
                    // complete with the decoded type
                    return output
                } catch {
                    // if there was a decoding error, complete with that error
                    throw HTTPClientError(responseCode: 400, cause: error)
                }
            } .flatMapErrorThrowing { error -> OutputType in
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
            if let durationMetricDetails = durationMetricDetails {
                durationMetricDetails.1.recordMicroseconds(Date().timeIntervalSince(durationMetricDetails.0))
            }
        }
        
        return future
    }
}
