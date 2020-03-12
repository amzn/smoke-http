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
//  HTTPClientInvocationDelegate.swift
//  SmokeHTTPClient
//

import Foundation
import AsyncHTTPClient
import Logging

public protocol HTTPClientInvocationDelegate {
    var specifyContentHeadersForZeroLengthBody: Bool { get }

    func addClientSpecificHeaders<InvocationReportingType: HTTPClientInvocationReporting>(
        additionalHeaders: [(String, String)],
        invocationReporting: InvocationReportingType) -> [(String, String)]

    func handleErrorResponses<InvocationReportingType: HTTPClientInvocationReporting>(
        response: HTTPClient.Response, responseBodyData: Data?,
        invocationReporting: InvocationReportingType) -> HTTPClientError?
}

public struct DefaultHTTPClientInvocationDelegate: HTTPClientInvocationDelegate {
    public let specifyContentHeadersForZeroLengthBody: Bool = true

    public func addClientSpecificHeaders<InvocationReportingType: HTTPClientInvocationReporting>(
            additionalHeaders: [(String, String)],
            invocationReporting: InvocationReportingType) -> [(String, String)] {
        return []
    }

    public func handleErrorResponses<InvocationReportingType: HTTPClientInvocationReporting>(
            response: HTTPClient.Response, responseBodyData: Data?,
            invocationReporting: InvocationReportingType) -> HTTPClientError? {
        return nil
    }
}
