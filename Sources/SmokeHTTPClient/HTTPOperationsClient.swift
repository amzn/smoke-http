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
//  HTTPClient.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import AsyncHTTPClient
import Logging

internal struct HttpHeaderNames {
    /// Content-Length Header
    static let contentLength = "Content-Length"

    /// Content-Type Header
    static let contentType = "Content-Type"
}

public struct HTTPOperationsClient {
    /// The server hostname to contact for requests from this client.
    public let endpointHostName: String
    /// The server port to connect to.
    public let endpointPort: Int
    /// The content type of the payload being sent.
    public let contentType: String
    /// Delegate that provides client-specific logic for handling HTTP requests
    public let clientDelegate: HTTPClientDelegate
    /// What scheme to use for the endpoint
    let endpointScheme: String
    
    /// The TLSConfiguration to use for connections from this client
    private let wrappedHttpClient: HTTPClient
    
    /**
     Initializer.

     - Parameters:
         - endpointHostName: The server hostname to contact for requests from this client.
         - endpointPort: The server port to connect to.
         - contentType: The content type of the payload being sent by this client.
         - clientDelegate: Delegate for the HTTP client that provides client-specific logic for handling HTTP requests.
         - channelInboundHandlerDelegate: Delegate for the HTTP channel inbound handler that provides client-specific logic
         -                                around HTTP request/response settings.
         - connectionTimeoutSeconds: The time in second the client should wait for a response. The default is 10 seconds.
         - eventLoopProvider: Provides the event loop to be used by the client.
                              If not specified, the client will create a new multi-threaded event loop
                              with the number of threads specified by `System.coreCount`.
     */
    public init(endpointHostName: String,
                endpointPort: Int,
                contentType: String,
                clientDelegate: HTTPClientDelegate,
                connectionTimeoutSeconds: Int64 = 10,
                eventLoopProvider: HTTPClient.EventLoopGroupProvider = .createNew) {
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.clientDelegate = clientDelegate
        
        let tlsConfiguration = clientDelegate.getTLSConfiguration()
        if tlsConfiguration != nil {
            self.endpointScheme = "https"
        } else {
            self.endpointScheme = "http"
        }
        
        let timeoutValue = TimeAmount.seconds(connectionTimeoutSeconds)
        let timeout = HTTPClient.Configuration.Timeout(read: timeoutValue)
        let clientConfiguration = HTTPClient.Configuration(
            tlsConfiguration: tlsConfiguration,
            timeout: timeout,
            ignoreUncleanSSLShutdown: true)
        self.wrappedHttpClient = HTTPClient(eventLoopGroupProvider: eventLoopProvider,
                                            configuration: clientConfiguration)
    }
    
    /**
     Gracefully shuts down the eventloop if owned by this client.
     This function is idempotent and will handle being called multiple
     times.
     */
    public func close() throws {
        try wrappedHttpClient.syncShutdown()
    }
    
    func executeAsync<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Result<HTTPResponseComponents, HTTPClientError>) -> (),
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
            where InputType: HTTPRequestInputProtocol {

        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort

        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath,
            invocationReporting: invocationContext.reporting)

        let pathWithQuery = requestComponents.pathWithQuery

        let endpoint = "\(self.endpointScheme)://\(endpointHostName):\(endpointPort)\(pathWithQuery)"
        let sendPath = pathWithQuery
        let sendBody = requestComponents.body
        let additionalHeaders = requestComponents.additionalHeaders

        let logger = invocationContext.reporting.logger
        logger.debug("Sending \(httpMethod) request to endpoint: \(endpoint) at path: \(sendPath).")
                
        guard let url = URL(string: endpoint) else {
            throw HTTPError.invalidRequest("Request endpoint '\(endpoint)' not valid URL.")
        }
                
        let parameters = HTTPRequestParameters(contentType: contentType,
                                               endpointUrl: url,
                                               endpointPath: sendPath,
                                               httpMethod: httpMethod,
                                               bodyData: sendBody,
                                               additionalHeaders: additionalHeaders)
                
        var requestHeaders = getRequestHeaders(
            parameters: parameters,
            invocationContext: invocationContext)
                
        let outwardsRequestContext = invocationContext.reporting.traceContext.handleOutwardsRequestStart(
            method: httpMethod, uri: endpointPath,
            logger: logger,
            internalRequestId: invocationContext.reporting.internalRequestId,
            headers: &requestHeaders, bodyData: sendBody)
                
        let request = try HTTPClient.Request(url: endpoint, method: httpMethod,
                                             headers: requestHeaders, body: .data(sendBody))
                
 
        let responseFuture = self.wrappedHttpClient.execute(request: request)
        responseFuture.whenComplete { result in
            self.handleCompleteResponse(invocationContext: invocationContext,
                                        outwardsRequestContext: outwardsRequestContext,
                                        completion: completion,
                                        result: result)
        }
                
        return responseFuture
    }
    
    /*
     Handles when the response has been completely received.
     */
    private func handleCompleteResponse<InvocationReportingType: HTTPClientInvocationReporting,
                HandlerDelegateType: HTTPClientInvocationDelegate>(
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            outwardsRequestContext: InvocationReportingType.TraceContextType.OutwardsRequestContext,
            completion: @escaping (Result<HTTPResponseComponents, HTTPClientError>) -> (),
            result: Result<HTTPClient.Response, Error>) {
        let invocationReporting = invocationContext.reporting
        let logger = invocationReporting.logger
        
        switch result {
        case .success(let response):
            let headers = getHeadersFromResponse(response: response)
            
            let bodyData: Data?
            if var bodyBuffer = response.body {
                let byteBufferSize = bodyBuffer.readableBytes
                bodyData = bodyBuffer.readData(length: byteBufferSize)
            } else {
                bodyData = nil
            }
            
            let responseComponents = HTTPResponseComponents(headers: headers,
                                                            body: bodyData)
            
            let isSuccess: Bool
            switch response.status {
            case .ok, .created, .accepted, .nonAuthoritativeInformation, .noContent, .resetContent, .partialContent:
                isSuccess = true
            default:
                isSuccess = false
            }

            // if the response status is ok
            if isSuccess {
                invocationReporting.traceContext.handleOutwardsRequestSuccess(
                    outwardsRequestContext: outwardsRequestContext,
                    logger: logger,
                    internalRequestId: invocationReporting.internalRequestId,
                    response: response, bodyData: bodyData)
                
                // complete with the response data (potentially empty)
                completion(.success(responseComponents))
                return
            }

            // Handle client delegated errors
            if let error = invocationContext.handlerDelegate.handleErrorResponses(
                    response: response, responseBodyData: bodyData,
                    invocationReporting: invocationReporting) {
                invocationReporting.traceContext.handleOutwardsRequestFailure(
                    outwardsRequestContext: outwardsRequestContext,
                    logger: logger,
                    internalRequestId: invocationReporting.internalRequestId,
                    response: response, bodyData: bodyData, error: error)
                
                completion(.failure(error))
                return
            }

            let responseError: HTTPClientError
            do {
                 let errorProvider: (HTTPClient.Response, HTTPResponseComponents, InvocationReportingType) throws
                    -> HTTPClientError = self.clientDelegate.getResponseError
                // attempt to get the error from the provider
                responseError = try errorProvider(response, responseComponents, invocationReporting)
            } catch let error as HTTPClientError {
                responseError = error
            } catch {
                // if the provider throws an error, use this error
                responseError = HTTPClientError(responseCode: 400, cause: error)
            }
            
            invocationReporting.traceContext.handleOutwardsRequestFailure(
                outwardsRequestContext: outwardsRequestContext,
                logger: logger,
                internalRequestId: invocationReporting.internalRequestId,
                response: response, bodyData: bodyData, error: responseError)

            // complete with the error
            completion(.failure(responseError))
            
        case .failure(let error):
            let cause = HTTPError.badResponse("Request failed")
            let wrappingError = HTTPClientError(responseCode: 400, cause: cause)
            
            invocationContext.reporting.traceContext.handleOutwardsRequestFailure(
                outwardsRequestContext: outwardsRequestContext,
                logger: logger,
                internalRequestId: invocationReporting.internalRequestId,
                response: nil, bodyData: nil, error: error)

            // complete with this error
            completion(.failure(wrappingError))
        }
    }
    
    private func getHeadersFromResponse(response: HTTPClient.Response) -> [(String, String)] {
        let headers: [(String, String)] = response.headers.map { header in
            return (header.name, header.value)
        }
        
        return headers
    }
    
    private func getRequestHeaders<InvocationReportingType: HTTPClientInvocationReporting,
                HandlerDelegateType: HTTPClientInvocationDelegate>(
            parameters: HTTPRequestParameters,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> HTTPHeaders {
        let delegate = invocationContext.handlerDelegate
        
        var headers = delegate.addClientSpecificHeaders(
            parameters: parameters,
            invocationReporting: invocationContext.reporting)

        let bodyData = parameters.bodyData
        // TODO: Move headers out to HTTPClient for UrlRequest
        if bodyData.count > 0 || delegate.specifyContentHeadersForZeroLengthBody {
            headers.append((HttpHeaderNames.contentType, contentType))
            headers.append((HttpHeaderNames.contentLength, "\(bodyData.count)"))
        }
        headers.append(("User-Agent", "SmokeHTTPClient"))
        headers.append(("Accept", "*/*"))
        
        return HTTPHeaders(headers)
    }
}
