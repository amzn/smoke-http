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
//  HTTPClientDelegate.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import ClientRuntime
import AwsCommonRuntimeKit

/**
 Delegate protocol that handles client-specific logic.
 */
public protocol HTTPClientDelegate {

    /// Gets the error corresponding to a client response body on the response head and body data.
    func getResponseError<InvocationReportingType: HTTPClientInvocationReporting>(
        response: HttpResponse,
        responseComponents: HTTPResponseComponents,
        invocationReporting: InvocationReportingType) throws -> HTTPClientError

    /**
     Gets the encoded input body and path with a query string for a client request.

     - Parameters:
        - input: The input used to define the request.
        - httpPath: The http path for the request.
     */
    func encodeInputAndQueryString<InputType, InvocationReportingType: HTTPClientInvocationReporting>(
        input: InputType,
        httpPath: String,
        invocationReporting: InvocationReportingType) throws -> HTTPRequestComponents
    where InputType: HTTPRequestInputProtocol

    /// Gets the decoded output base on the response body.
    func decodeOutput<OutputType, InvocationReportingType: HTTPClientInvocationReporting>(
        output: Data?,
        headers: [(String, String)],
        invocationReporting: InvocationReportingType) throws -> OutputType
    where OutputType: HTTPResponseOutputProtocol

    /// Gets the TLS configuration required for HTTPClient's use-case.
    /// If this function returns nil, the HTTPClient will send requests as
    /// unencrypted http.
    func getTLSConnectionOptions() -> TLSConnectionOptions?
}

public extension HTTPClientDelegate {
    /// Overrides the protocol requirement by default, returning the default TLS configuration if no customization is needed
    func getTLSConnectionOptions() -> TLSConnectionOptions? {
        return getDefaultTLSConnectionOptions()
    }
    
    /// Default TLS configuration if no customization is needed. Simply turns certificate verification off if debugging, otherwise
    /// provides the default TLSConfiguration.
    func getDefaultTLSConnectionOptions() -> TLSConnectionOptions? {

        // To help debugging, turn off certificate verification when locally calling.
        #if DEBUG
        return nil
        #else
        return TLSConnectionOptions(
            context: SDKDefaultIO.shared.tlsContext,
            serverName: endpoint.host
        )
        #endif
    }
}
