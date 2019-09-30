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
//  HTTPClient.swift
//  SmokeHTTPClient
//

import Foundation
import NIO
import NIOHTTP1
import NIOSSL
import NIOTLS
import LoggerAPI

public class HTTPClient {
    /// The server hostname to contact for requests from this client.
    public let endpointHostName: String
    /// The server port to connect to.
    public let endpointPort: Int
    /// The content type of the payload being sent.
    public let contentType: String
    /// Delegate that provides client-specific logic for handling HTTP requests
    public let clientDelegate: HTTPClientDelegate
    /// The connection timeout in seconds
    public let connectionTimeoutSeconds: Int64
    
    /// The TLSConfiguration to use for connections from this client
    private let tlsConfiguration: TLSConfiguration?
    
    /**
     Enumeration specifying how the event loop is provided for a channel established by this client.
     */
    public enum EventLoopProvider {
        /// The client will create a new EventLoopGroup to be used for channels created from
        /// this client. The EventLoopGroup will be closed when this client is closed.
        case spawnNewThreads
        /// The client will use the provided EventLoopGroup for channels created from
        /// this client. This EventLoopGroup will not be closed when this client is closed.
        case use(EventLoopGroup)
    }
    
    private enum State {
        case active
        case closing
        case closed
    }
    
    private let closureDispatchGroup: DispatchGroup
    private var state: State
    private var stateLock: NSLock
    
    static let unexpectedClosureType =
        HTTPError.connectionError("Http request was unexpectedly closed without returning a response.")

    /// The event loop used by requests/responses from this client
    let eventLoopGroup: EventLoopGroup
    let ownEventLoopGroup: Bool

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
                eventLoopProvider: EventLoopProvider = .spawnNewThreads) {
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.clientDelegate = clientDelegate
        self.tlsConfiguration = clientDelegate.getTLSConfiguration()
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
        self.stateLock = NSLock()
        self.state = .active
        self.closureDispatchGroup = DispatchGroup()
        // enter the DispatchGroup during initialization so waiting for the
        // closure of an initalized or started client will wait
        closureDispatchGroup.enter()

        switch eventLoopProvider {
        case .spawnNewThreads:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.ownEventLoopGroup = true
        case .use(let existingEventLoopGroup):
            self.eventLoopGroup = existingEventLoopGroup
            self.ownEventLoopGroup = false
        }
    }

    /**
     De-initializer. Report if the client is not closed.
     */
    deinit {
        guard isClosed() else {
            return Log.error("HTTPClient was not closed properly prior to de-initialization.")
        }
    }
    
    /**
     Gracefully shuts down the eventloop if owned by this client.
     This function is idempotent and will handle being called multiple
     times.
     */
    public func close() {
        let doCloseClient = updateOnClosureStart()
        
        guard doCloseClient else {
            // already closing or closed, nothing to do
            return
        }
        
        // if this client owns the EventLoopGroup
        if ownEventLoopGroup {
            eventLoopGroup.shutdownGracefully { _ in
                self.closeClient()
            }
        } else {
            // nothing to do as the EventLoopGroup isn't owned by the client,
            // close immediately
            closeClient()
        }
    }
    
    private func closeClient() {
        self.updateStateOnClosureComplete()
        
        // release any waiters for closure
        self.closureDispatchGroup.leave()
    }
    
    /**
     Waits for the client to be closed. If close() is not called,
     this will block forever.
     */
    public func wait() {
        if !isClosed() {
            closureDispatchGroup.wait()
        }
    }

    func executeAsync<InputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<HTTPResponseComponents>) -> (),
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> EventLoopFuture<Channel>
            where InputType: HTTPRequestInputProtocol {

        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort

        let sslHandler: NIOSSLClientHandler?
        let endpointScheme: String
        if let tlsConfiguration = tlsConfiguration {
            let sslContext = try NIOSSLContext(configuration: tlsConfiguration)
            sslHandler = try NIOSSLClientHandler(context: sslContext,
                                                 serverHostname: endpointHostName)
            endpointScheme = "https"
        } else {
            sslHandler = nil
            endpointScheme = "http"
        }

        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath)

        let pathWithQuery = requestComponents.pathWithQuery

        let endpoint = "\(endpointScheme)://\(endpointHostName):\(endpointPort)\(pathWithQuery)"
        let sendPath = pathWithQuery
        let sendBody = requestComponents.body
        let additionalHeaders = requestComponents.additionalHeaders

        guard let url = URL(string: endpoint) else {
            throw HTTPError.invalidRequest("Request endpoint '\(endpoint)' not valid URL.")
        }

        Log.verbose("Sending \(httpMethod) request to endpoint: \(endpoint) at path: \(sendPath).")

        let handler = HTTPClientChannelInboundHandler(contentType: contentType,
                                                      endpointUrl: url,
                                                      endpointPath: sendPath,
                                                      httpMethod: httpMethod,
                                                      bodyData: sendBody,
                                                      additionalHeaders: additionalHeaders,
                                                      errorProvider: clientDelegate.getResponseError,
                                                      completion: completion,
                                                      channelInboundHandlerDelegate: handlerDelegate)

        let bootstrap: ClientBootstrap
        // include the sslHandler in the channel pipeline if there one
        if let sslHandler = sslHandler {
            bootstrap = ClientBootstrap(group: eventLoopGroup)
                .connectTimeout(TimeAmount.seconds(self.connectionTimeoutSeconds))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHandler(sslHandler).flatMap {
                        channel.pipeline.addHTTPClientHandlers().flatMap {
                            channel.pipeline.addHandler(handler)
                        }
                    }
            }
        } else {
            bootstrap = ClientBootstrap(group: eventLoopGroup)
                .connectTimeout(TimeAmount.seconds(self.connectionTimeoutSeconds))
                .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .channelInitializer { channel in
                    channel.pipeline.addHTTPClientHandlers().flatMap {
                        channel.pipeline.addHandler(handler)
                    }
            }
        }

        return bootstrap.connect(host: endpointHostName, port: endpointPort)
    }
    
    /**
     Updates the Lifecycle state on a closure request.
     
     - Returns: if the closure request should be acted upon (and the client closed).
     Will be false if the client is already closing or has closed.
     */
    private func updateOnClosureStart() -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        let doCloseClient: Bool
        switch state {
        case .active:
            state = .closing
            
            doCloseClient = true
        case .closing, .closed:
            // nothing to do; already closing or closed
            doCloseClient = false
        }
        
        return doCloseClient
    }
    
    /**
     Updates the Lifecycle state on closure completion.
     */
    private func updateStateOnClosureComplete() {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        guard case .closing = state else {
            fatalError("HTTPClientError closure completed when in expected state: \(state)")
        }
        
        state = .closed
    }
    
    /**
     Indicates if the client is currently closed.
     
     - Returns: if the client is currently closed.
     */
    private func isClosed() -> Bool {
        stateLock.lock()
        defer {
            stateLock.unlock()
        }
        
        if case .closed = state {
            return true
        }
        
        return false
    }
}
