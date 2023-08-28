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
//  MockHTTPInvocationClient.swift
//  SmokeHTTPClient
//

import Foundation
import NIOHTTP1

public protocol EmptyInitializable {
    init()
}

public enum MockHTTPInvocationClientErrors: Error {
    case cannotInitializeEmptyOutput(outputType: String)
    case mismatchingOutputTypes(outputType: String, overrideOutputType: String)
}

public struct MockHTTPInvocationClient<OverrideInputType: HTTPRequestInputProtocol, OverrideOutputType: HTTPResponseOutputProtocol>: HTTPInvocationClientProtocol {
    public typealias ExecuteWithoutOutputFunctionType = (
        _ endpoint: URL?,
        _ endpointPath: String,
        _ httpMethod: HTTPMethod,
        _ operation: String?,
        _ input: OverrideInputType) async throws -> Void

    public typealias ExecuteWithOutputFunctionType = (
        _ endpoint: URL?,
        _ endpointPath: String,
        _ httpMethod: HTTPMethod,
        _ operation: String?,
        _ input: OverrideInputType) async throws -> OverrideOutputType

    let executeWithoutOutputOverride: ExecuteWithoutOutputFunctionType?
    let executeWithOutputOverride: ExecuteWithOutputFunctionType?

    public init(
        executeWithoutOutputOverride: ExecuteWithoutOutputFunctionType? = nil,
        executeWithOutputOverride: ExecuteWithOutputFunctionType? = nil) {
            self.executeWithoutOutputOverride = executeWithoutOutputOverride
            self.executeWithOutputOverride = executeWithOutputOverride
    }
    
    public func shutdown() async throws {}

    public func executeRetriableWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws {
            if let executeWithoutOutputOverride = executeWithoutOutputOverride,
                let convertedInput = input as? OverrideInputType {
                try await executeWithoutOutputOverride(endpoint, endpointPath, httpMethod, operation, convertedInput)
            }
    }

    public func executeRetriableWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws -> OutputType {
            if let executeWithOutputOverride = executeWithOutputOverride,
                let convertedInput = input as? OverrideInputType {
                let output = try await executeWithOutputOverride(endpoint, endpointPath, httpMethod, operation, convertedInput) as? OutputType
                guard let output = output else {
                    throw MockHTTPInvocationClientErrors.mismatchingOutputTypes(outputType: String(describing: OutputType.self), overrideOutputType: String(describing: OverrideOutputType.self))
                }

                return output
            }

            return try getDefaultOutput()
    }

    public func executeWithoutOutput<InputType: HTTPRequestInputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws {
            if let executeWithoutOutputOverride = executeWithoutOutputOverride,
                let convertedInput = input as? OverrideInputType {
                try await executeWithoutOutputOverride(endpoint, endpointPath, httpMethod, operation, convertedInput)
            }
    }

    public func executeWithOutput<InputType: HTTPRequestInputProtocol, OutputType: HTTPResponseOutputProtocol>(
        endpoint: URL?,
        endpointPath: String,
        httpMethod: HTTPMethod,
        operation: String?,
        input: InputType) async throws -> OutputType {
            if let executeWithOutputOverride = executeWithOutputOverride,
                let convertedInput = input as? OverrideInputType {
                let output = try await executeWithOutputOverride(endpoint, endpointPath, httpMethod, operation, convertedInput) as? OutputType
                guard let output = output else {
                    throw MockHTTPInvocationClientErrors.mismatchingOutputTypes(outputType: String(describing: OutputType.self), overrideOutputType: String(describing: OverrideOutputType.self))
                }

                return output
            }

            return try getDefaultOutput()
    }

    private func getDefaultOutput<OutputType: HTTPResponseOutputProtocol>() throws -> OutputType {
        guard let initializableType = OutputType.self as? EmptyInitializable.Type,
            let initializedInstance = initializableType.init() as? OutputType else {
            throw MockHTTPInvocationClientErrors.cannotInitializeEmptyOutput(outputType: String(describing: OutputType.self))
        }

        return initializedInstance
    }
}

public struct MockNoHTTPOutput: HTTPResponseOutputProtocol, EmptyInitializable {
    public typealias BodyType = String
    public typealias HeadersType = String

    public static func compose(bodyDecodableProvider: () throws -> BodyType, headersDecodableProvider: () throws -> HeadersType) throws -> MockNoHTTPOutput {
        return Self()
    }

    public init() {}
}

public typealias DefaultMockHTTPInvocationClient = MockHTTPInvocationClient<NoHTTPRequestInput, MockNoHTTPOutput>
