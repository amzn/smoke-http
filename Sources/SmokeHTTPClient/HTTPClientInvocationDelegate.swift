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
import NIOHTTP1
import Logging

public struct HTTPRequestParameters {
    /// The content type of the payload being sent.
    public let contentType: String
    /// The endpoint url to request a response from.
    public let endpointUrl: URL
    /// The path to request a response from.
    public let endpointPath: String
    /// The http method to use for the request.
    public let httpMethod: HTTPMethod
    /// The request body data to use.
    public let bodyData: Data
    /// Any additional headers to add
    public let additionalHeaders: [(String, String)]
    
    /**
     Initializer.
     
     - Parameters:
        - contentType: The endpoint url to request a response from.
        - endpointUrl: The endpoint url to request a response from.
        - endpointPath: The path to request a response from.
        - httpMethod: The http method to use for the request.
        - bodyData: The request body data to use.
        - additionalHeaders: Any additional headers to add
     */
    public init(contentType: String,
                endpointUrl: URL,
                endpointPath: String,
                httpMethod: HTTPMethod,
                bodyData: Data,
                additionalHeaders: [(String, String)]) {
        self.contentType = contentType
        self.endpointUrl = endpointUrl
        self.endpointPath = endpointPath
        self.httpMethod = httpMethod
        self.bodyData = bodyData
        self.additionalHeaders = additionalHeaders
    }
}

public protocol HTTPClientInvocationDelegate {
    var specifyContentHeadersForZeroLengthBody: Bool { get }

    func addClientSpecificHeaders<InvocationReportingType: HTTPClientInvocationReporting>(
        parameters: HTTPRequestParameters,
        invocationReporting: InvocationReportingType) -> [(String, String)]

    func handleErrorResponses<InvocationReportingType: HTTPClientInvocationReporting>(
        response: HTTPClient.Response, responseBodyData: Data?,
        invocationReporting: InvocationReportingType) -> HTTPClientError?
}

public struct DefaultHTTPClientInvocationDelegate: HTTPClientInvocationDelegate {
    public let specifyContentHeadersForZeroLengthBody: Bool = true

    public func addClientSpecificHeaders<InvocationReportingType: HTTPClientInvocationReporting>(
            parameters: HTTPRequestParameters,
            invocationReporting: InvocationReportingType) -> [(String, String)] {
        return []
    }

    public func handleErrorResponses<InvocationReportingType: HTTPClientInvocationReporting>(
            response: HTTPClient.Response, responseBodyData: Data?,
            invocationReporting: InvocationReportingType) -> HTTPClientError? {
        return nil
    }
}
