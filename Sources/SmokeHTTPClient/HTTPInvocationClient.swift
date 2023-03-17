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
//  HTTPInvocationClient.swift
//  SmokeHTTPClient
//

import Foundation
import AsyncHTTPClient
import NIOHTTP1

public protocol HTTPInvocationClientProtocol {
     func shutdown() async throws

    func executeRetriableWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws

    func executeRetriableWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws -> OutputType

    func executeWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws

    func executeWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws -> OutputType
}

/**
 Provides a wrapper around a `HTTPOperationsClient` that creates its invocation context at initialization.
 */
public struct HTTPInvocationClient<TraceContextType: InvocationTraceContext, HandlerDelegateType: HTTPClientInvocationDelegate>: HTTPInvocationClientProtocol {
    let httpClient: HTTPOperationsClient
    let ownsHttpClients: Bool
    let retryConfiguration: HTTPClientRetryConfiguration
    let retryOnErrorProvider: (HTTPClientError) -> Bool
    let invocationContext: HTTPClientInvocationContext<StandardHTTPClientInvocationReporting<TraceContextType>, HandlerDelegateType>

    // Only Swift >= 5.7 supports type inference from default expressions
    #if swift(>=5.7)
    public init(
        endpointHostName: String = "", // If empty, client will have to provide endpoint in each individual request
        endpointPort: Int = 443,
        contentType: String = "application/json",
        clientDelegate: HTTPClientDelegate = HTTPClientJSONDelegate(),
        timeoutConfiguration: HTTPClient.Configuration.Timeout = .init(
            connect: .seconds(10), read: .seconds(10)),
        connectionPoolConfiguration: HTTPClient.Configuration.ConnectionPool? = nil,
        eventLoopProvider: HTTPClient.EventLoopGroupProvider = .createNew,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        retryOnErrorProvider: @escaping (SmokeHTTPClient.HTTPClientError) -> Bool = { error in error.isRetriable() },
        invocationAttributes: HTTPClientInvocationAttributes,
        invocationTraceContext: TraceContextType,
        invocationDelegate: HandlerDelegateType = DefaultHTTPClientInvocationDelegate(),
        invocationMetrics: HTTPClientInvocationMetrics? = nil) {
            let httpClient = HTTPOperationsClient(
                endpointHostName: endpointHostName,
                endpointPort: endpointPort,
                contentType: contentType,
                clientDelegate: clientDelegate,
                timeoutConfiguration: timeoutConfiguration,
                eventLoopProvider: eventLoopProvider,
                connectionPoolConfiguration: connectionPoolConfiguration)

            self.init(
                httpClient: httpClient,
                ownsHttpClients: false,
                retryConfiguration: retryConfiguration,
                retryOnErrorProvider: retryOnErrorProvider,
                invocationAttributes: invocationAttributes,
                invocationTraceContext: invocationTraceContext,
                invocationDelegate: invocationDelegate,
                invocationMetrics: invocationMetrics)
    }

    public init(
        httpClient: HTTPOperationsClient,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        retryOnErrorProvider: @escaping (SmokeHTTPClient.HTTPClientError) -> Bool = { error in error.isRetriable() },
        invocationAttributes: HTTPClientInvocationAttributes,
        invocationTraceContext: TraceContextType,
        invocationDelegate: HandlerDelegateType = DefaultHTTPClientInvocationDelegate(),
        invocationMetrics: HTTPClientInvocationMetrics? = nil) {
            self.init(
                httpClient: httpClient,
                ownsHttpClients: false,
                retryConfiguration: retryConfiguration,
                retryOnErrorProvider: retryOnErrorProvider,
                invocationAttributes: invocationAttributes,
                invocationTraceContext: invocationTraceContext,
                invocationDelegate: invocationDelegate,
                invocationMetrics: invocationMetrics)
    }
    #else
    public init(
        endpointHostName: String = "", // If empty, client will have to provide endpoint in each individual request
        endpointPort: Int = 443,
        contentType: String = "application/json",
        clientDelegate: HTTPClientDelegate = HTTPClientJSONDelegate(),
        timeoutConfiguration: HTTPClient.Configuration.Timeout = .init(
            connect: .seconds(10), read: .seconds(10)),
        connectionPoolConfiguration: HTTPClient.Configuration.ConnectionPool? = nil,
        eventLoopProvider: HTTPClient.EventLoopGroupProvider = .createNew,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        retryOnErrorProvider: @escaping (SmokeHTTPClient.HTTPClientError) -> Bool = { error in error.isRetriable() },
        invocationAttributes: HTTPClientInvocationAttributes,
        invocationTraceContext: TraceContextType,
        invocationDelegate: HandlerDelegateType,
        invocationMetrics: HTTPClientInvocationMetrics? = nil) {
            let httpClient = HTTPOperationsClient(
                endpointHostName: endpointHostName,
                endpointPort: endpointPort,
                contentType: contentType,
                clientDelegate: clientDelegate,
                timeoutConfiguration: timeoutConfiguration,
                eventLoopProvider: eventLoopProvider,
                connectionPoolConfiguration: connectionPoolConfiguration)

            self.init(
                httpClient: httpClient,
                ownsHttpClients: false,
                retryConfiguration: retryConfiguration,
                retryOnErrorProvider: retryOnErrorProvider,
                invocationAttributes: invocationAttributes,
                invocationTraceContext: invocationTraceContext,
                invocationDelegate: invocationDelegate,
                invocationMetrics: invocationMetrics)
    }

    public init(
        httpClient: HTTPOperationsClient,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        retryOnErrorProvider: @escaping (SmokeHTTPClient.HTTPClientError) -> Bool = { error in error.isRetriable() },
        invocationAttributes: HTTPClientInvocationAttributes,
        invocationTraceContext: TraceContextType,
        invocationDelegate: HandlerDelegateType,
        invocationMetrics: HTTPClientInvocationMetrics? = nil) {
            self.init(
                httpClient: httpClient,
                ownsHttpClients: false,
                retryConfiguration: retryConfiguration,
                retryOnErrorProvider: retryOnErrorProvider,
                invocationAttributes: invocationAttributes,
                invocationTraceContext: invocationTraceContext,
                invocationDelegate: invocationDelegate,
                invocationMetrics: invocationMetrics)
    }
    #endif

    private init(
        httpClient: HTTPOperationsClient,
        ownsHttpClients: Bool,
        retryConfiguration: HTTPClientRetryConfiguration = .default,
        retryOnErrorProvider: @escaping (SmokeHTTPClient.HTTPClientError) -> Bool = { error in error.isRetriable() },
        invocationAttributes: HTTPClientInvocationAttributes,
        invocationTraceContext: TraceContextType,
        invocationDelegate: HandlerDelegateType,
        invocationMetrics: HTTPClientInvocationMetrics? = nil) {
            self.httpClient = httpClient

            self.ownsHttpClients = ownsHttpClients
            self.retryConfiguration = retryConfiguration
            self.retryOnErrorProvider = retryOnErrorProvider

            let reporting = StandardHTTPClientInvocationReporting(
                internalRequestId: invocationAttributes.internalRequestId,
                traceContext: invocationTraceContext,
                logger: invocationAttributes.logger,
                eventLoop: invocationAttributes.eventLoop,
                outwardsRequestAggregator: invocationAttributes.outwardsRequestAggregator,
                successCounter: invocationMetrics?.successCounter,
                failure5XXCounter: invocationMetrics?.failure5XXCounter,
                failure4XXCounter: invocationMetrics?.failure4XXCounter,
                retryCountRecorder: invocationMetrics?.retryCountRecorder,
                latencyTimer: invocationMetrics?.latencyTimer)

            self.invocationContext = HTTPClientInvocationContext(reporting: reporting, handlerDelegate: invocationDelegate)
    }

    /**
     Gracefully shuts down this client. This function is idempotent and
     will handle being called multiple times. Will return when shutdown is complete.
     */
    public func shutdown() async throws {
        if self.ownsHttpClients {
            try await self.httpClient.shutdown()
        }
    }

    public func executeRetriableWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType) async throws {
            guard endpoint != nil || self.httpClient.endpointHostName != "" else {
                throw HTTPError.badRequest("No endpoint host name was specified.")
            }

            try await self.httpClient.executeRetriableWithoutOutput(
                endpointOverride: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: input,
                invocationContext: self.invocationContext,
                retryConfiguration: self.retryConfiguration,
                retryOnError: self.retryOnErrorProvider)
    }

    public func executeRetriableWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType) async throws -> OutputType {
            guard endpoint != nil || self.httpClient.endpointHostName != "" else {
                throw HTTPError.badRequest("No endpoint host name was specified.")
            }

            return try await self.httpClient.executeRetriableWithOutput(
                endpointOverride: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: input,
                invocationContext: self.invocationContext,
                retryConfiguration: self.retryConfiguration,
                retryOnError: self.retryOnErrorProvider)
    }

    public func executeWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType) async throws {
            guard endpoint != nil || self.httpClient.endpointHostName != "" else {
                throw HTTPError.badRequest("No endpoint host name was specified.")
            }

            try await self.httpClient.executeWithoutOutput(
                endpointOverride: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: input,
                invocationContext: self.invocationContext)
    }

    public func executeWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL? = nil,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String? = nil,
        input: InputType) async throws -> OutputType {
            guard endpoint != nil || self.httpClient.endpointHostName != "" else {
                throw HTTPError.badRequest("No endpoint host name was specified.")
            }

            return try await self.httpClient.executeWithOutput(
                endpointOverride: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: input,
                invocationContext: self.invocationContext)
    }
}
