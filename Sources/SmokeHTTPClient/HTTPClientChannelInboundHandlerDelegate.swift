// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  HTTPClientChannelInboundHandlerDelegate.swift
//  SmokeHTTPClient
//

import Foundation
import NIOHTTP1
import Logging

public protocol HTTPClientChannelInboundHandlerDelegate {
    var specifyContentHeadersForZeroLengthBody: Bool { get }

    func addClientSpecificHeaders(handler: HTTPClientChannelInboundHandler, invocationReporting: HTTPClientInvocationReporting) -> [(String, String)]

    func handleErrorResponses(responseHead: HTTPResponseHead, responseBodyData: Data?,
                              invocationReporting: HTTPClientInvocationReporting) -> HTTPClientError?
}

public struct DefaultHTTPClientChannelInboundHandlerDelegate: HTTPClientChannelInboundHandlerDelegate {
    public let specifyContentHeadersForZeroLengthBody: Bool = true

    public func addClientSpecificHeaders(handler: HTTPClientChannelInboundHandler,
                                         invocationReporting: HTTPClientInvocationReporting) -> [(String, String)] {
        return []
    }

    public func handleErrorResponses(responseHead: HTTPResponseHead, responseBodyData: Data?,
                                     invocationReporting: HTTPClientInvocationReporting) -> HTTPClientError? {
        return nil
    }
}
