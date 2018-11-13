// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
import NIOOpenSSL
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
    public let connectionTimeoutSeconds: Int
    
    private static let unexpectedClosureType =
        HTTPError.connectionError("Http request was unexpectedly closed without returning a response.")

    /// The event loop used by requests/responses from this client
    let eventLoopGroup: MultiThreadedEventLoopGroup

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
     */
    public init(endpointHostName: String,
                endpointPort: Int,
                contentType: String,
                clientDelegate: HTTPClientDelegate,
                connectionTimeoutSeconds: Int = 10) {
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.clientDelegate = clientDelegate
        self.connectionTimeoutSeconds = connectionTimeoutSeconds

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    /**
     De-initializer. Shuts down the event loop group when this instance is deallocated.
     */
    deinit {
        do {
            try eventLoopGroup.syncShutdownGracefully()
        } catch {
            Log.error("Unable to shut down event loop group: \(error)")
        }
    }

    /**
     Submits a request that will return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with the response body or any error.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    public func executeAsyncWithOutput<InputType, OutputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<OutputType>) -> (),
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
        where InputType: HTTPRequestInputProtocol, OutputType: Decodable {
            return try executeAsyncWithOutput(
                endpointOverride: endpointOverride,
                endpointPath: endpointPath,
                httpMethod: httpMethod,
                input: input,
                completion: completion,
                asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<HTTPResult<OutputType>>(),
                handlerDelegate: handlerDelegate)
    }

    /**
     Submits a request that will return a response body to this client asynchronously.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with the response body or any error.
     - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    public func executeAsyncWithOutput<InputType, OutputType, InvocationStrategyType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<OutputType>) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
        InvocationStrategyType.OutputType == HTTPResult<OutputType>, OutputType: Decodable {

        var hasComplete = false
        let requestDelegate = clientDelegate
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        // that will decode the returned body into the desired decodable type.
        let wrappingCompletion: (HTTPResult<Data?>) -> () = { (rawResult) in
            let result: HTTPResult<OutputType>

            switch rawResult {
            case .error(let error):
                // its an error; complete with the provided error
                result = .error(error)
            case .response(let response):
                // we are expecting a response body
                guard let response = response else {
                    // complete with a bad response error
                    return completion(.error(HTTPError.badResponse("Unexpected empty response.")))
                }

                do {
                    // decode the provided body into the desired type
                    let output: OutputType = try requestDelegate.decodeOutput(output: response)

                    // complete with the decoded type
                    result = .response(output)
                } catch {
                    // if there was a decoding error, complete with that error
                    result = .error(error)
                }
            }

            asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
            hasComplete = true
        }

        // submit the asynchronous request
        let channel = try executeAsync(endpointOverride: endpointOverride,
                                       endpointPath: endpointPath,
                                       httpMethod: httpMethod,
                                       input: input,
                                       completion: wrappingCompletion,
                                       handlerDelegate: handlerDelegate)

        channel.closeFuture.whenComplete {
            // if this channel is being closed and no response has been recorded
            if !hasComplete {
                completion(.error(HTTPClient.unexpectedClosureType))
            }
        }

        return channel
    }

    /**
     Submits a request that will not return a response body to this client asynchronously.
     The completion handler's execution will be scheduled on DispatchQueue.global()
     rather than executing on a thread from SwiftNIO.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with an error if one occurs or nil otherwise.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    public func executeAsyncWithoutOutput<InputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Error?) -> (),
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
            where InputType: HTTPRequestInputProtocol {
                return try executeAsyncWithoutOutput(
                    endpointOverride: endpointOverride,
                    endpointPath: endpointPath,
                    httpMethod: httpMethod,
                    input: input,
                    completion: completion,
                    asyncResponseInvocationStrategy: GlobalDispatchQueueAsyncResponseInvocationStrategy<Error?>(),
                    handlerDelegate: handlerDelegate)
    }

    /**
     Submits a request that will not return a response body to this client asynchronously.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - completion: Completion handler called with an error if one occurs or nil otherwise.
     - asyncResponseInvocationStrategy: The invocation strategy for the response from this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     */
    public func executeAsyncWithoutOutput<InputType, InvocationStrategyType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (Error?) -> (),
            asyncResponseInvocationStrategy: InvocationStrategyType,
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
            where InputType: HTTPRequestInputProtocol, InvocationStrategyType: AsyncResponseInvocationStrategy,
            InvocationStrategyType.OutputType == Error? {

        var hasComplete = false
        // create a wrapping completion handler to pass to the ChannelInboundHandler
        let wrappingCompletion: (HTTPResult<Data?>) -> () = { (rawResult) in
            let result: Error?

            switch rawResult {
            case .error(let error):
                // its an error, complete with this error
                result = error
            case .response:
                // its a successful completion, complete with an empty error.
                result = nil
            }

            asyncResponseInvocationStrategy.invokeResponse(response: result, completion: completion)
            hasComplete = true
        }

        // submit the asynchronous request
        let channel = try executeAsync(endpointOverride: endpointOverride,
                                       endpointPath: endpointPath,
                                       httpMethod: httpMethod,
                                       input: input,
                                       completion: wrappingCompletion,
                                       handlerDelegate: handlerDelegate)

        channel.closeFuture.whenComplete {
            // if this channel is being closed and no response has been recorded
            if !hasComplete {
                completion(HTTPClient.unexpectedClosureType)
            }
        }

        return channel
    }

    /**
     Submits a request that will return a response body to this client synchronously.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     - Returns: the response body.
     - Throws: If an error occurred during the request.
     */
    public func executeSyncWithOutput<InputType, OutputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> OutputType
            where InputType: HTTPRequestInputProtocol, OutputType: Codable {

        var responseResult: HTTPResult<OutputType>?
        let completedSemaphore = DispatchSemaphore(value: 0)

        let completion: (HTTPResult<OutputType>) -> () = { result in
            responseResult = result
            completedSemaphore.signal()
        }

        let channel = try executeAsyncWithOutput(endpointOverride: endpointOverride,
                                                 endpointPath: endpointPath,
                                                 httpMethod: httpMethod,
                                                 input: input,
                                                 completion: completion,
                                                 // the completion handler can be safely executed on a SwiftNIO thread
                                                 asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<HTTPResult<OutputType>>(),
                                                 handlerDelegate: handlerDelegate)

        channel.closeFuture.whenComplete {
            // if this channel is being closed and no response has been recorded
            if responseResult == nil {
                responseResult = .error(HTTPClient.unexpectedClosureType)
                completedSemaphore.signal()
            }
        }

        Log.verbose("Waiting for response from \(endpointOverride?.host ?? endpointHostName) ...")
        completedSemaphore.wait()

        guard let result = responseResult else {
            throw HTTPError.connectionError("Http request was closed without returning a response.")
        }

        Log.verbose("Got response from \(endpointOverride?.host ?? endpointHostName) - response received: \(result)")

        switch result {
        case .error(let error):
            throw error
        case .response(let response):
            return response
        }
    }

    private struct AsyncErrorResult {
        let error: Error?
    }

    /**
     Submits a request that will not return a response body to this client synchronously.

     - Parameters:
     - endpointPath: The endpoint path for this request.
     - httpMethod: The http method to use for this request.
     - input: the input body data to send with this request.
     - handlerDelegate: the delegate used to customize the request's channel handler.
     - Throws: If an error occurred during the request.
     */
    public func executeSyncWithoutOutput<InputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws
            where InputType: HTTPRequestInputProtocol {
        var responseError: AsyncErrorResult?
        let completedSemaphore = DispatchSemaphore(value: 0)

        let completion: (Error?) -> () = { error in
            responseError = AsyncErrorResult(error: error)
            completedSemaphore.signal()
        }

        let channel = try executeAsyncWithoutOutput(endpointOverride: endpointOverride,
                                                    endpointPath: endpointPath,
                                                    httpMethod: httpMethod,
                                                    input: input,
                                                    completion: completion,
                                                    // the completion handler can be safely executed on a SwiftNIO thread
                                                    asyncResponseInvocationStrategy: SameThreadAsyncResponseInvocationStrategy<Error?>(),
                                                    handlerDelegate: handlerDelegate)

        channel.closeFuture.whenComplete {
            // if this channel is being closed and no response has been recorded
            if responseError == nil {
                responseError = AsyncErrorResult(error: HTTPClient.unexpectedClosureType)
                completedSemaphore.signal()
            }
        }

        completedSemaphore.wait()

        if let error = responseError?.error {
            throw error
        }
    }

    func executeAsync<InputType>(
            endpointOverride: URL? = nil,
            endpointPath: String,
            httpMethod: HTTPMethod,
            input: InputType,
            completion: @escaping (HTTPResult<Data?>) -> (),
            handlerDelegate: HTTPClientChannelInboundHandlerDelegate) throws -> Channel
            where InputType: HTTPRequestInputProtocol {

        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort

        let tlsConfiguration = clientDelegate.getTLSConfiguration()
        let sslContext = try SSLContext(configuration: tlsConfiguration)
        let sslHandler = try OpenSSLClientHandler(context: sslContext,
                                                  serverHostname: endpointHostName)

        let requestComponents = try clientDelegate.encodeInputAndQueryString(
            input: input,
            httpPath: endpointPath)

        let pathWithQuery = requestComponents.pathWithQuery

        let endpoint = "https://\(endpointHostName):\(endpointPort)\(pathWithQuery)"
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

        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .connectTimeout(TimeAmount.seconds(self.connectionTimeoutSeconds))
            .channelInitializer { channel in
                channel.pipeline.add(handler: sslHandler).then {
                    channel.pipeline.addHTTPClientHandlers().then {
                        channel.pipeline.add(handler: handler)
                    }
                }
        }

        return try bootstrap.connect(host: endpointHostName, port: endpointPort).wait()
    }
}
