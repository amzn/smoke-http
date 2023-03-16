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
import AsyncHTTPClient
import NIOSSL
import NIOHTTP1
import NIOCore
import Logging
import HTTPHeadersCoding

/**
 Delegate protocol that handles client-specific logic.
 */
public protocol HTTPClientDelegate {

    /// Gets the error corresponding to a client response body on the response head and body data.
    func getResponseError<InvocationReportingType: HTTPClientInvocationReporting>(
        response: HTTPClient.Response,
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
    func getTLSConfiguration() -> TLSConfiguration?
}

public extension HTTPClientDelegate {
    /// Overrides the protocol requirement by default, returning the default TLS configuration if no customization is needed
    func getTLSConfiguration() -> TLSConfiguration? {
        return getDefaultTLSConfiguration()
    }
    
    /// Default TLS configuration if no customization is needed. Simply turns certificate verification off if debugging, otherwise
    /// provides the default TLSConfiguration.
    func getDefaultTLSConfiguration() -> TLSConfiguration? {

        // To help debugging, turn off certificate verification when locally calling.
        #if DEBUG
        let certificateVerification = CertificateVerification.none
        #else
        let certificateVerification = CertificateVerification.fullVerification
        #endif
        
        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = certificateVerification

        return tlsConfiguration
    }
}

public struct HTTPClientJSONDelegate: HTTPClientDelegate {
    public init() {}

    struct HTTPClientErrorDetails: Error, CustomStringConvertible {
        let response: AsyncHTTPClient.HTTPClient.Response

        var description: String {
            var message = "HTTP request failed with error \(response.status.reasonPhrase). Response headers are \(response.headers)."
            if response.status.mayHaveResponseBody,
                let body = response.body,
                let bodyString = body.getString(at: 0, length: body.readableBytes) {
                message += " Response body is '\(bodyString)'."
            }

            return message
        }
    }

    public func getResponseError<InvocationReportingType>(
        response: AsyncHTTPClient.HTTPClient.Response,
        responseComponents: HTTPResponseComponents,
        invocationReporting: InvocationReportingType) throws -> HTTPClientError 
    where InvocationReportingType : HTTPClientCoreInvocationReporting, InvocationReportingType : HTTPClientInvocationMetrics {
        return HTTPClientError(responseCode: Int(response.status.code), cause: HTTPClientErrorDetails(response: response))
    }

    public func encodeInputAndQueryString<InputType, InvocationReportingType>(
        input: InputType,
        httpPath: String,
        invocationReporting: InvocationReportingType) throws -> HTTPRequestComponents
    where InputType : HTTPRequestInputProtocol,
        InvocationReportingType : HTTPClientCoreInvocationReporting,
        InvocationReportingType : HTTPClientInvocationMetrics {
            let bodyData: Data
            if let bodyEncodable = input.bodyEncodable {
                bodyData = try JSONEncoder().encode(bodyEncodable)
            } else {
                bodyData = Data()
            }
            
            return HTTPRequestComponents(
                pathWithQuery: httpPath,
                additionalHeaders: [],
                body: bodyData)
    }

    public func decodeOutput<OutputType, InvocationReportingType>(
        output: Data?,
        headers: [(String, String)],
        invocationReporting: InvocationReportingType) throws -> OutputType
    where OutputType : HTTPResponseOutputProtocol,
        InvocationReportingType : HTTPClientCoreInvocationReporting,
        InvocationReportingType : HTTPClientInvocationMetrics {
            // Convert output to a debug string only if trace logging is enabled
            invocationReporting.logger.trace("Attempting to decode result data from JSON to \(OutputType.self)",
                                             metadata: ["body": "\(output.debugString)"])

            func bodyDecodableProvider() throws -> OutputType.BodyType {
                // we are expecting a response body
                guard let responseBody = output else {
                    throw HTTPError.badResponse("Unexpected empty response.")
                }
                
                return try JSONDecoder().decode(OutputType.BodyType.self, from: responseBody)
            }
            
            func headersDecodableProvider() throws -> OutputType.HeadersType {
                let headersDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
                return try headersDecoder.decode(OutputType.HeadersType.self,
                                                 from: headers)
            }
            
            return try OutputType.compose(bodyDecodableProvider: bodyDecodableProvider,
                                          headersDecodableProvider: headersDecodableProvider)
    }
}

private extension Data {
    var debugString: String {
        return String(data: self, encoding: .utf8) ?? ""
    }
}

private extension Optional where Wrapped == Data {
    var debugString: String {
        switch self {
        case .some(let wrapped):
            return wrapped.debugString
        case .none:
            return ""
        }
    }
}
