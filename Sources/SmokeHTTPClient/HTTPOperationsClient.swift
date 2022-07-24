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
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import AsyncHTTPClient
import NIOFoundationCompat
import Logging

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
    let endpointScheme: String
    
    /// The `HTTPClient` used for this instance
    private let wrappedHttpClient: HTTPClient
    
    public var eventLoopGroup: EventLoopGroup {
        return self.wrappedHttpClient.eventLoopGroup
    }
    
    /**
     Initializer.

     - Parameters:
         - endpointHostName: The server hostname to contact for requests from this client.
         - endpointPort: The server port to connect to.
         - contentType: The content type of the payload being sent by this client.
         - clientDelegate: Delegate for the HTTP client that provides client-specific logic for handling HTTP requests.
         - connectionTimeoutSeconds: The time in second the client should wait for a response. The default is 10 seconds.
         - eventLoopProvider: Provides the event loop to be used by the client.
                              If not specified, the client will create a new multi-threaded event loop
                              with the number of threads specified by `System.coreCount`.
         - optional configuration for the connection pool. If not provided, the default configuration is used.
     */
    public init(endpointHostName: String,
                endpointPort: Int,
                contentType: String,
                clientDelegate: HTTPClientDelegate,
                connectionTimeoutSeconds: Int64 = 10,
                eventLoopProvider: HTTPClient.EventLoopGroupProvider = .createNew,
                connectionPoolConfiguration connectionPoolConfigurationOptional: HTTPClient.Configuration.ConnectionPool? = nil) {
        let timeoutValue = TimeAmount.seconds(connectionTimeoutSeconds)
        let timeoutConfiguration = HTTPClient.Configuration.Timeout(connect: timeoutValue, read: timeoutValue)
        
        self.init(endpointHostName: endpointHostName,
                  endpointPort: endpointPort,
                  contentType: contentType,
                  clientDelegate: clientDelegate,
                  timeoutConfiguration: timeoutConfiguration,
                  eventLoopProvider: eventLoopProvider,
                  connectionPoolConfiguration: connectionPoolConfigurationOptional)
    }
    
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
                timeoutConfiguration: HTTPClient.Configuration.Timeout,
                eventLoopProvider: HTTPClient.EventLoopGroupProvider = .createNew,
                connectionPoolConfiguration connectionPoolConfigurationOptional: HTTPClient.Configuration.ConnectionPool? = nil) {
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
        
        let connectionPool = connectionPoolConfigurationOptional ?? HTTPClient.Configuration.ConnectionPool()
        
        let clientConfiguration = HTTPClient.Configuration(
            tlsConfiguration: tlsConfiguration,
            timeout: timeoutConfiguration,
            connectionPool: connectionPool,
            ignoreUncleanSSLShutdown: true)
        self.wrappedHttpClient = HTTPClient(eventLoopGroupProvider: eventLoopProvider,
                                            configuration: clientConfiguration)
    }
    
    /**
     Gracefully shuts down the eventloop if owned by this client.
     This function is idempotent and will handle being called multiple
     times. Will block until shutdown is complete.
     */
    public func syncShutdown() throws {
        try wrappedHttpClient.syncShutdown()
    }
    
    // renamed `syncShutdown` to make it clearer this version of shutdown will block.
    @available(*, deprecated, renamed: "syncShutdown")
    public func close() throws {
        try wrappedHttpClient.syncShutdown()
    }
    
    /**
     Gracefully shuts down the eventloop if owned by this client.
     This function is idempotent and will handle being called multiple
     times. Will return when shutdown is complete.
     */
#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)
    public func shutdown() async throws {
        return try await withUnsafeThrowingContinuation { cont in
            self.wrappedHttpClient.shutdown { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
#endif
    
    func executeAsync<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Result<HTTPResponseComponents, HTTPClientError>) -> (),
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws -> EventLoopFuture<HTTPClient.Response>
            where InputType: HTTPRequestInputProtocol {
        let (responseFuture, outwardsRequestContext) = try performExecuteAsync(endpointOverride: endpointOverride,
                                                                               endpointPath: endpointPath,
                                                                               httpMethod: httpMethod,
                                                                               input: input,
                                                                               invocationContext: invocationContext)

        responseFuture.whenComplete { result in
            do {
                let responseComponents = try self.handleCompleteResponse(invocationContext: invocationContext,
                                                                         outwardsRequestContext: outwardsRequestContext,
                                                                         result: result)
                completion(.success(responseComponents))
            } catch let error as HTTPClientError {
                completion(.failure(error))
            } catch {
                // if a non-HTTPClientError is thrown, wrap it
                let responseError = HTTPClientError(responseCode: 400, cause: error)
                completion(.failure(responseError))
            }
        }
                
        return responseFuture
    }
    
    func executeAsEventLoopFuture<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) -> EventLoopFuture<HTTPResponseComponents>
            where InputType: HTTPRequestInputProtocol {
        do {
            let (responseFuture, outwardsRequestContext) = try performExecuteAsync(endpointOverride: endpointOverride,
                                                                                   endpointPath: endpointPath,
                                                                                   httpMethod: httpMethod,
                                                                                   input: input,
                                                                                   invocationContext: invocationContext)
            return responseFuture.flatMapThrowing { successResult in
                // a response has been successfully received; this reponse may be a successful response
                // and generate a `HTTPResponseComponents` instance or be a failure response and cause
                // a SmokeHTTPClient.HTTPClientError error to be thrown
                return try self.handleCompleteResponseThrowingClientError(invocationContext: invocationContext,
                                                                          outwardsRequestContext: outwardsRequestContext,
                                                                          result: .success(successResult))
            } .flatMapErrorThrowing { error in
                // if this error has been thrown from just above
                if let typedError = error as? SmokeHTTPClient.HTTPClientError {
                    // just rethrow the error
                    throw typedError
                }
                
                // a response wasn't even able to be generated (for example due to a connection error)
                // make sure this error is thrown correctly as a SmokeHTTPClient.HTTPClientError
                return try self.handleCompleteResponseThrowingClientError(invocationContext: invocationContext,
                                                                          outwardsRequestContext: outwardsRequestContext,
                                                                          result: .failure(error))
            }
        } catch {
            let eventLoop = invocationContext.reporting.eventLoop ?? self.eventLoopGroup.next()
            
            let promise = eventLoop.makePromise(of: HTTPResponseComponents.self)
            
            promise.fail(error)
            
            return promise.futureResult
        }
    }
    
    // To maintain the existing behaviour of async functions, this function will throw for synchronous setup errors and fail
    // the future otherwise.
    private func performExecuteAsync<InputType, InvocationReportingType: HTTPClientInvocationReporting, HandlerDelegateType: HTTPClientInvocationDelegate>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>) throws
        -> (EventLoopFuture<HTTPClient.Response>, InvocationReportingType.TraceContextType.OutwardsRequestContext)
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
        logger.trace("Sending \(httpMethod) request to endpoint: \(endpoint) at path: \(sendPath).")
                
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
            method: httpMethod, uri: endpoint,
            logger: logger,
            internalRequestId: invocationContext.reporting.internalRequestId,
            headers: &requestHeaders, bodyData: sendBody)
                
        let request = try HTTPClient.Request(url: endpoint, method: httpMethod,
                                             headers: requestHeaders, body: .data(sendBody))
                
        let responseFuture: EventLoopFuture<HTTPClient.Response>
        // if an event loop is provided that can be used with this client
        if let eventLoopOverride = invocationContext.reporting.eventLoop,
           self.eventLoopGroup.makeIterator().contains(where: { $0 === eventLoopOverride }) {
            responseFuture = self.wrappedHttpClient.execute(request: request,
                                                            eventLoop: .delegateAndChannel(on: eventLoopOverride))
        } else {
            responseFuture = self.wrappedHttpClient.execute(request: request)
        }
        
        return (responseFuture, outwardsRequestContext)
    }
    
    private func handleCompleteResponseThrowingClientError<InvocationReportingType: HTTPClientInvocationReporting,
                HandlerDelegateType: HTTPClientInvocationDelegate>(
            invocationContext: HTTPClientInvocationContext<InvocationReportingType, HandlerDelegateType>,
            outwardsRequestContext: InvocationReportingType.TraceContextType.OutwardsRequestContext,
            result: Result<HTTPClient.Response, Error>) throws -> HTTPResponseComponents {
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
            result: Result<HTTPClient.Response, Error>) throws -> HTTPResponseComponents {
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
            throw responseError
            
        case .failure(let error):
            let wrappingError: HTTPClientError
            
            let errorDescription = String(describing: error)
            
            switch error {
            // for retriable HTTPClientErrors
            case let clientError as AsyncHTTPClient.HTTPClientError where isRetriableHTTPClientError(clientError: clientError):
                let cause = HTTPError.connectionError(errorDescription)
                wrappingError = HTTPClientError(responseCode: 500, cause: cause)
            // for non-retriable HTTPClientErrors
            case _ as AsyncHTTPClient.HTTPClientError:
                let cause = HTTPError.badResponse(errorDescription)
                wrappingError = HTTPClientError(responseCode: 400, cause: cause)
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
    
    private func isRetriableHTTPClientError(clientError: AsyncHTTPClient.HTTPClientError) -> Bool {
        // special case read, connect, connection pool or tls handshake timeouts and remote connection closed errors
        // to a 500 error to allow for retries
        if clientError == AsyncHTTPClient.HTTPClientError.readTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.connectTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.tlsHandshakeTimeout
                || clientError == AsyncHTTPClient.HTTPClientError.remoteConnectionClosed
                || clientError == AsyncHTTPClient.HTTPClientError.getConnectionFromPoolTimeout {
            return true
        }
        
        return false
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
