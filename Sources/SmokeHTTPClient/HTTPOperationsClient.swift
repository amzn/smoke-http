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
//  HTTPClient.swift
//  SmokeHTTPClient
//

import Foundation
import Logging
import ClientRuntime

internal struct HttpHeaderNames {
    /// Content-Length Header
    static let contentLength = "Content-Length"

    /// Content-Type Header
    static let contentType = "Content-Type"
}

/**
 A wrapper around a `HTTPClient` instance that handles operation request and responses.
 */
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
    let endpointScheme: ProtocolType
    
    private let engine: HttpClientEngine
    private let offTaskAsyncExecutor = OffTaskAsyncExecutor()
    
    /**
     Initializer.

     - Parameters:
         - endpointHostName: The server hostname to contact for requests from this client.
         - endpointPort: The server port to connect to.
         - contentType: The content type of the payload being sent by this client.
         - clientDelegate: Delegate for the HTTP client that provides client-specific logic for handling HTTP requests.
         - timeoutConfiguration: The timeout configuration to use
         - eventLoopProvider: Provides the event loop to be used by the client.
                              If not specified, the client will create a new multi-threaded event loop
                              with the number of threads specified by `System.coreCount`.
         - optional configuration for the connection pool. If not provided, the default configuration is used.
     */
    public init(endpointHostName: String,
                endpointPort: Int,
                contentType: String,
                clientDelegate: HTTPClientDelegate,
                runtimeConfig: ClientRuntime.SDKRuntimeConfiguration) {
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.clientDelegate = clientDelegate
        self.engine = runtimeConfig.httpClientEngine
        
        let tlsConnectionOptions = clientDelegate.getTLSConnectionOptions()
        if tlsConnectionOptions != nil {
            self.endpointScheme = .https
        } else {
            self.endpointScheme = .http
        }
    }
}
 
extension HTTPOperationsClient {
    func execute<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HttpMethodType,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws
    -> HTTPResponseComponents where InputType: HTTPRequestInputProtocol {
        let (request, outwardsRequestContext) = try await getRequest(endpointOverride: endpointOverride,
                                                                     endpointPath: endpointPath,
                                                                     httpMethod: httpMethod,
                                                                     input: input,
                                                                     invocationContext: invocationContext)
        
        do {
            let response = try await self.engine.execute(request: request)
            
            // a response has been successfully received; this reponse may be a successful response
            // and generate a `HTTPResponseComponents` instance or be a failure response and cause
            // a SmokeHTTPClient.HTTPClientError error to be thrown
            return try await self.offTaskAsyncExecutor.execute {
                try self.handleCompleteResponseThrowingClientError(invocationContext: invocationContext,
                                                                   outwardsRequestContext: outwardsRequestContext,
                                                                   result: .success(response))
            }
        } catch {
            // if this error has been thrown from just above
            if let typedError = error as? SmokeHTTPClient.HTTPClientError {
                // just rethrow the error
                throw typedError
            }
            
            // a response wasn't even able to be generated (for example due to a connection error)
            // make sure this error is thrown correctly as a SmokeHTTPClient.HTTPClientError
            return try await self.offTaskAsyncExecutor.execute {
                try self.handleCompleteResponseThrowingClientError(invocationContext: invocationContext,
                                                                   outwardsRequestContext: outwardsRequestContext,
                                                                   result: .failure(error))
            }
        }
    }
    
    private func getRequest<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HttpMethodType,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) async throws
    -> (SdkHttpRequest, InvocationReportingType.TraceContextType.OutwardsRequestContext)
    where InputType: HTTPRequestInputProtocol {
        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort

        let requestComponents = try await self.offTaskAsyncExecutor.execute {
            return try clientDelegate.encodeInputAndQueryString(
                input: input,
                httpPath: endpointPath,
                invocationReporting: invocationContext.reporting)
        }

        let endpoint = Endpoint(host: endpointHostName,
                                path: requestComponents.path,
                                port: Int16(endpointPort),
                                queryItems: requestComponents.queryItems,
                                protocolType: self.endpointScheme)
        let sendBody = requestComponents.body
        let additionalHeaders = requestComponents.additionalHeaders

        let logger = invocationContext.reporting.logger
        logger.trace("Sending \(httpMethod) request to endpoint: \(endpointHostName) at path: \(requestComponents.path).")
        
        guard let url = endpoint.url else {
            throw HTTPError.invalidRequest("Request endpoint '\(endpoint)' not valid URL.")
        }
                
        let parameters = HTTPRequestParameters(contentType: contentType,
                                               endpointUrl: url,
                                               endpointPath: requestComponents.path,
                                               httpMethod: httpMethod,
                                               bodyData: sendBody,
                                               additionalHeaders: additionalHeaders)
                
        var requestHeaders = getRequestHeaders(
            parameters: parameters,
            invocationContext: invocationContext)
                
        let outwardsRequestContext = invocationContext.reporting.traceContext.handleOutwardsRequestStart(
            method: httpMethod, uri: endpoint,
            logger: logger,
            internalRequestId: invocationContext.reporting.internalRequestId,
            headers: &requestHeaders, bodyData: sendBody)
                
        let request = SdkHttpRequest(method: httpMethod,
                                     endpoint: endpoint,
                                     headers: requestHeaders,
                                     queryItems: requestComponents.queryItems,
                                     body: .data(sendBody))
                
        return (request, outwardsRequestContext)
    }
    
    private func handleCompleteResponseThrowingClientError<InvocationReportingType: HTTPClientInvocationReporting,
                HandlerDelegateType: HTTPClientInvocationDelegate>(
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            outwardsRequestContext: InvocationReportingType.TraceContextType.OutwardsRequestContext,
            result: Result<HttpResponse, Error>) throws -> HTTPResponseComponents {
        do {
            return try handleCompleteResponse(invocationContext: invocationContext,
                                              outwardsRequestContext: outwardsRequestContext,
                                              result: result)
        } catch {
            if error is SmokeHTTPClient.HTTPClientError {
                throw error
            } else {
                // if a non-HTTPClientError is thrown, wrap it
                throw SmokeHTTPClient.HTTPClientError(responseCode: 400, cause: error)
            }
        }
    }
    
    /*
     Handles when the response has been completely received.
     */
    private func handleCompleteResponse<InvocationReportingType: HTTPClientInvocationReporting,
                HandlerDelegateType: HTTPClientInvocationDelegate>(
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            outwardsRequestContext: InvocationReportingType.TraceContextType.OutwardsRequestContext,
            result: Result<HttpResponse, Error>) throws -> HTTPResponseComponents {
        let invocationReporting = invocationContext.reporting
        let logger = invocationReporting.logger
        
        switch result {
        case .success(let response):
            let headers = getHeadersFromResponse(response: response)
            
            let bodyData: Data?
            switch response.body {
            case .data(let theBodyData):
                bodyData = theBodyData
            case .stream:
                fatalError("Streaming not implemented.")
            case .none:
                bodyData = nil
            }
            
            let responseComponents = HTTPResponseComponents(headers: headers, body: bodyData)
            
            let isSuccess: Bool
            switch response.statusCode {
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
                return responseComponents
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
                
                throw error
            }

            let responseError: HTTPClientError
            do {
                 let errorProvider: (HttpResponse, HTTPResponseComponents, InvocationReportingType) throws
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
            throw responseError
            
        case .failure(let error):
            let wrappingError: HTTPClientError
            
            let errorDescription = String(describing: error)
            
            switch error {
            // by default treat all other errors as 500 so they can be retried
            default:
                let cause = HTTPError.connectionError(errorDescription)
                wrappingError = HTTPClientError(responseCode: 500, cause: cause)
            }
            
            invocationContext.reporting.traceContext.handleOutwardsRequestFailure(
                outwardsRequestContext: outwardsRequestContext,
                logger: logger,
                internalRequestId: invocationReporting.internalRequestId,
                response: nil, bodyData: nil, error: error)

            // complete with this error
            throw wrappingError
        }
    }
    
    private func getHeadersFromResponse(response: HttpResponse) -> [(String, String)] {
        let headers: [(String, String)] = response.headers.headers.flatMap { header in
            return header.value.map { value in
                return (header.name, value)
            }
        }
        
        return headers
    }
    
    private func getRequestHeaders<InvocationReportingType: HTTPClientInvocationReporting,
                                   HandlerDelegateType: HTTPClientInvocationDelegate>(
            parameters: HTTPRequestParameters,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>)
    -> Headers {
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
        
        return Headers(headers.asMap())
    }
}

private extension Array where Element == (String, String) {
    func asMap() -> [String: [String]] {
        var theMap: [String: [String]] = [:]
        
        self.forEach { (key, value) in
            if var existingValues = theMap[key] {
                existingValues.append(value)
                theMap[key] = existingValues
            } else {
                theMap[key] = [value]
            }
        }
        
        return theMap
    }
}
