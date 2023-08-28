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
//  MockHTTPClientInvocationClientTests.swift
//  SmokeHTTPClientTests
//

import XCTest
@testable import SmokeHTTPClient
@testable import NIOHTTP1

private struct TestHTTPRequestInput: HTTPRequestInputProtocol, Equatable {
    typealias QueryType = String
    typealias PathType = String
    typealias BodyType = String
    typealias AdditionalHeadersType = String

    let queryEncodable: QueryType?
    let pathEncodable: PathType?
    let bodyEncodable: BodyType?
    let additionalHeadersEncodable: AdditionalHeadersType?
    let pathPostfix: String?

    init(body: String) {
        self.queryEncodable = nil
        self.pathEncodable = nil
        self.bodyEncodable = body
        self.additionalHeadersEncodable = nil
        self.pathPostfix = nil
    }

    static func == (lhs: TestHTTPRequestInput, rhs: TestHTTPRequestInput) -> Bool {
        lhs.queryEncodable == rhs.queryEncodable &&
            lhs.pathEncodable == rhs.pathEncodable &&
            lhs.bodyEncodable == rhs.bodyEncodable &&
            lhs.additionalHeadersEncodable == rhs.additionalHeadersEncodable &&
            lhs.pathPostfix == rhs.pathPostfix
    }
}

private struct TestHTTPResponseOutput: HTTPResponseOutputProtocol, Equatable {
    typealias BodyType = String
    typealias HeadersType = String

    let body: String
    let headers: String

    static func compose(bodyDecodableProvider: () throws -> BodyType, headersDecodableProvider: () throws -> HeadersType) throws -> Self {
        return try Self(body: bodyDecodableProvider(), headers: headersDecodableProvider())
    }

    init(body: String, headers: String) {
        self.body = body
        self.headers = headers
    }

    static func == (lhs: TestHTTPResponseOutput, rhs: TestHTTPResponseOutput) -> Bool {
        lhs.body == rhs.body &&
            lhs.headers == rhs.headers
    }
}

final class MockHTTPClientInvocationClientTests: XCTestCase {
    func testExecuteWithoutOutput() async {
        let expectedEndpoint = URL(string: "http://www.amazon.com")
        let expectedEndpointPath = "/p/a/t/h"
        let expectedHTTPMethod = HTTPMethod.GET
        let expectedOperation = "operation"

        let expectedInput = TestHTTPRequestInput(body: "input")

        var executeWithoutOutputCalled = false
        func executeWithoutOutput(
            endpoint: URL?,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String?,
            input: TestHTTPRequestInput) {
                executeWithoutOutputCalled = true
                XCTAssertEqual(endpoint, expectedEndpoint)
                XCTAssertEqual(endpointPath, expectedEndpointPath)
                XCTAssertEqual(httpMethod, expectedHTTPMethod)
                XCTAssertEqual(operation, expectedOperation)
                XCTAssertEqual(input, expectedInput)
        }

        let mockWithOverride = MockHTTPInvocationClient<TestHTTPRequestInput, TestHTTPResponseOutput>(executeWithoutOutputOverride: executeWithoutOutput)
        let mockWithoutOverride = MockHTTPInvocationClient<TestHTTPRequestInput, TestHTTPResponseOutput>()

        do {
            try await mockWithOverride.executeRetriableWithoutOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertTrue(executeWithoutOutputCalled)

            executeWithoutOutputCalled = false
            try await mockWithOverride.executeWithoutOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertTrue(executeWithoutOutputCalled)

            executeWithoutOutputCalled = false
            try await mockWithoutOverride.executeRetriableWithoutOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertFalse(executeWithoutOutputCalled)

            try await mockWithoutOverride.executeWithoutOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertFalse(executeWithoutOutputCalled)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testExecuteWithOutput() async {
        let expectedEndpoint = URL(string: "http://www.amazon.com")
        let expectedEndpointPath = "/p/a/t/h"
        let expectedHTTPMethod = HTTPMethod.GET
        let expectedOperation = "operation"

        let expectedInput = TestHTTPRequestInput(body: "input")
        let expectedOutput = TestHTTPResponseOutput(body: "output", headers: "")

        func executeWithOutput(
            _ endpoint: URL?,
            _ endpointPath: String,
            _ httpMethod: HTTPMethod,
            _ operation: String?,
            _ input: TestHTTPRequestInput) async throws -> TestHTTPResponseOutput {
                XCTAssertEqual(endpoint, expectedEndpoint)
                XCTAssertEqual(endpointPath, expectedEndpointPath)
                XCTAssertEqual(httpMethod, expectedHTTPMethod)
                XCTAssertEqual(operation, expectedOperation)
                XCTAssertEqual(input, expectedInput)

                return expectedOutput
        }

        let mockWithOverrides = MockHTTPInvocationClient<TestHTTPRequestInput, TestHTTPResponseOutput>(executeWithOutputOverride: executeWithOutput)
        let mockWithoutOverrides = MockHTTPInvocationClient<TestHTTPRequestInput, TestHTTPResponseOutput>()

        do {
            let output1: TestHTTPResponseOutput = try await mockWithOverrides.executeRetriableWithOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertEqual(expectedOutput, output1)

            let output2: TestHTTPResponseOutput = try await mockWithOverrides.executeWithOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertEqual(expectedOutput, output2)
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        do {
            // Cannot implicitly initialize an output
            let _: TestHTTPResponseOutput = try await mockWithoutOverrides.executeRetriableWithOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTFail("Expected error not thrown")
        } catch MockHTTPInvocationClientErrors.cannotInitializeEmptyOutput {
            // Expected error
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        do {
            // Cannot implicitly initialize an output
            let _: TestHTTPResponseOutput = try await mockWithoutOverrides.executeWithOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTFail("Expected error not thrown")
        } catch MockHTTPInvocationClientErrors.cannotInitializeEmptyOutput {
            // Expected error
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testExecuteWithAndWithoutOutput() async {
        let expectedEndpoint = URL(string: "http://www.amazon.com")
        let expectedEndpointPath = "/p/a/t/h"
        let expectedHTTPMethod = HTTPMethod.GET
        let expectedOperation = "operation"

        let expectedInput = TestHTTPRequestInput(body: "input")
        var executeWithoutOutputCalled = false
        func executeWithoutOutput(
            endpoint: URL?,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String?,
            input: TestHTTPRequestInput) {
                executeWithoutOutputCalled = true
                XCTAssertEqual(endpoint, expectedEndpoint)
                XCTAssertEqual(endpointPath, expectedEndpointPath)
                XCTAssertEqual(httpMethod, expectedHTTPMethod)
                XCTAssertEqual(operation, expectedOperation)
                XCTAssertEqual(input, expectedInput)
        }        
        
        let expectedOutput = TestHTTPResponseOutput(body: "output", headers: "")
        func executeWithOutput(
            _ endpoint: URL?,
            _ endpointPath: String,
            _ httpMethod: HTTPMethod,
            _ operation: String?,
            _ input: TestHTTPRequestInput) async throws -> TestHTTPResponseOutput {
                XCTAssertEqual(endpoint, expectedEndpoint)
                XCTAssertEqual(endpointPath, expectedEndpointPath)
                XCTAssertEqual(httpMethod, expectedHTTPMethod)
                XCTAssertEqual(operation, expectedOperation)
                XCTAssertEqual(input, expectedInput)

                return expectedOutput
        }

        let mock = MockHTTPInvocationClient(
            executeWithoutOutputOverride: executeWithoutOutput,
            executeWithOutputOverride: executeWithOutput)

        do {
            try await mock.executeWithoutOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertTrue(executeWithoutOutputCalled)

            let output: TestHTTPResponseOutput = try await mock.executeWithOutput(
                endpoint: expectedEndpoint,
                endpointPath: expectedEndpointPath,
                httpMethod: expectedHTTPMethod,
                operation: expectedOperation,
                input: expectedInput)
            XCTAssertEqual(expectedOutput, output)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDefaultMock() async {
        let endpoint = URL(string: "http://www.amazon.com")
        let endpointPath = "/p/a/t/h"
        let httpMethod = HTTPMethod.GET
        let operation = "operation"
        
        let mock = DefaultMockHTTPInvocationClient()

        do {
            try await mock.executeRetriableWithoutOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())

            try await mock.executeWithoutOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())

            let _: MockNoHTTPOutput = try await mock.executeRetriableWithOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())

            let _: MockNoHTTPOutput = try await mock.executeWithOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testExecuteWithTypeMismatch() async {
        let endpoint = URL(string: "http://www.amazon.com")
        let endpointPath = "/p/a/t/h"
        let httpMethod = HTTPMethod.GET
        let operation = "operation"

        var executeWithoutOutputCalled = false
        func executeWithoutOutput(
            endpoint: URL?,
            endpointPath: String,
            httpMethod: HTTPMethod,
            operation: String?,
            input: TestHTTPRequestInput) {
                executeWithoutOutputCalled = true
        }        
        
        let expectedOutput = TestHTTPResponseOutput(body: "output", headers: "")
        func executeWithOutput(
            _ endpoint: URL?,
            _ endpointPath: String,
            _ httpMethod: HTTPMethod,
            _ operation: String?,
            _ input: TestHTTPRequestInput) async throws -> TestHTTPResponseOutput {
                return expectedOutput
        }

        let mock = MockHTTPInvocationClient(
            executeWithoutOutputOverride: executeWithoutOutput,
            executeWithOutputOverride: executeWithOutput)

        do {
            // The override generic type doesn't match the request, the override is not executed
            try await mock.executeWithoutOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())
            XCTAssertFalse(executeWithoutOutputCalled)

            // The override generic input type doesn't match the request, the override is not executed.
            // The output is empty-initializable, so the request still succeeds
            let _: MockNoHTTPOutput = try await mock.executeWithOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        do {
            // The override generic input type doesn't match the request, the override is not executed.
            // The output is not empty-initializable, so the request fails
            let _: TestHTTPResponseOutput = try await mock.executeWithOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: NoHTTPRequestInput())
        } catch MockHTTPInvocationClientErrors.cannotInitializeEmptyOutput {
            // Expected error
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        do {
            // The override generic output type doesn't match the request, the request fails.
            let _: MockNoHTTPOutput = try await mock.executeWithOutput(
                endpoint: endpoint,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                operation: operation,
                input: TestHTTPRequestInput(body: "input"))
        } catch MockHTTPInvocationClientErrors.mismatchingOutputTypes {
            // Expected error
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
