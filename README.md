<p align="center">
<a href="https://github.com/amzn/smoke-http/actions">
<img src="https://github.com/amzn/smoke-http/actions/workflows/swift.yml/badge.svg?branch=main" alt="Build - Main Branch">
</a>
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.4|5.5|5.6-orange.svg?style=flat" alt="Swift 5.4, 5.5 and 5.6 Tested">
</a>
<img src="https://img.shields.io/badge/ubuntu-18.04|20.04-yellow.svg?style=flat" alt="Ubuntu 18.04 and 20.04 Tested">
<img src="https://img.shields.io/badge/CentOS-8-yellow.svg?style=flat" alt="CentOS 8 Tested">
<img src="https://img.shields.io/badge/AmazonLinux-2-yellow.svg?style=flat" alt="Amazon Linux 2 Tested">
<a href="https://gitter.im/SmokeServerSide">
<img src="https://img.shields.io/badge/chat-on%20gitter-ee115e.svg?style=flat" alt="Join the Smoke Server Side community on gitter">
</a>
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>

# SmokeHTTP

SmokeHTTP is a specialization of the generic HTTP client provided by [async-http-client](https://github.com/swift-server/async-http-client), providing the common functionality required to abstract service operations from the underlying HTTP protocol. This library is primarily used by [SmokeFramework](https://github.com/amzn/smoke-framework) and [SmokeAWS](https://github.com/amzn/smoke-aws). 

This library provides a number of features on top of those provided by async-http-client:
1. The `HTTPRequestInputProtocol` and `HTTPResponseOutputProtocol` protocols provide a mechanism to deconstruct an input type into the different components of a HTTP request and construct an output type from the components of a HTTP response respectively.
2. Protocol-based strategies for determining the threading-model for asynchronous completion handling.
3. Support for exponential backoff retries.
4. Logging and emission of invocation metrics.
5. An extension point for handing request-level tracing.

## SmokeHTTPClient

To use SmokeHTTPClient, a user can instantiate an `HTTPOperationsClient` in the constructor of their specific client with instantiated delegates (`HTTPClientDelegate`, `HTTPClientInvocationDelegate`) that are used to define client-specific logic.

## Support Policy

SmokeHTTP follows the same support policy as followed by SmokeAWS [here](https://github.com/amzn/smoke-aws/blob/master/docs/Support_Policy.md).

# Getting Started

## Step 1: Add the SmokeHTTP dependency

SmokeHTTP uses the Swift Package Manager. To use the framework, add the following dependency
to your Package.swift.

For swift-tools version 5.2 and greater:

```swift
dependencies: [
    .package(url: "https://github.com/amzn/smoke-http.git", from: "2.0.0")
]

.target(name: ..., dependencies: [
    ..., 
    .product(name: "SmokeHTTPClient", package: "smoke-http"),
]),
```

For swift-tools version 5.1 and prior:

```swift
dependencies: [
    .package(url: "https://github.com/amzn/smoke-http.git", from: "2.0.0")
]

.target(
    name: ...,
    dependencies: [..., "SmokeHTTPClient"]),
```

## Step 2: Construct a HTTPOperationsClient

Construct a HTTPClient using the following code:

```swift
import SmokeHTTPClient

let httpOperationsClient = HTTPOperationsClient(endpointHostName: endpointHostName,
                                                endpointPort: endpointPort,
                                                contentType: contentType,
                                                clientDelegate: clientDelegate,
                                                connectionTimeoutSeconds: connectionTimeoutSeconds,
                                                eventLoopProvider: = .createNew)
```

The inputs to this constructor are:
1. **endpointHostName**: The hostname to contact for invocations made by this client. Doesn't include the scheme or port. 
  * For example `dynamodb.us-west-2.amazonaws.com`.
2. **endpointPort**: The port to contact for invocations made by this client.
  * For example `443`.
3. **contentType**: The content type of the request body for invocations made by this client. 
  * For example `application/json`.
4. **clientDelegate**: An instance of a type conforming to the `HTTPClientDelegate` protocol.
5. **connectionTimeoutSeconds**: The timeout in seconds for requests made by this client.
6. **eventLoopProvider**: The provider of the event loop for this client. Defaults to creating a new event loop.

## Step 3: Execute an invocation of the HTTPOperationsClient

There are a number of variants of the execute call on the `HTTPOperationsClient`. Below describes one variant but all are broadly similar-

```
try httpOperationsClient.executeAsyncRetriableWithOutput(
            endpointOverride: nil,
            endpointPath = endpointPath,
            httpMethod: .GET,
            input: InputType,
            completion: completion,
            asyncResponseInvocationStrategy: asyncResponseInvocationStrategy,
            invocationContext: invocationContext,
            retryConfiguration: retryConfiguration,
            retryOnError: retryOnError)
```

The inputs to this function are:
1. **endpointOverride**: Overrides the hostname used for this invocation. Default to nil to use the endpoint provided during the initialization of the client.
2. **endpointPath**: The path to contact for this invocation.
3. **httpMethod**: The HTTPMethod for this invocation.
4. **input**: An instance of a type conforming to the `HTTPRequestInputProtocol` protocol.
5. **completion**: A closure of type `(Result<OutputType, HTTPClientError>) -> ()` used to handle the outcome of the invocation. `OutputType` must be a type that conforms to the  `HTTPResponseOutputProtocol` protocol.
6. **asyncResponseInvocationStrategy**: An invocation strategy for executing the completion handler. 
  *  [GlobalDispatchQueueAsyncResponseInvocationStrategy](https://github.com/amzn/smoke-http/blob/master/Sources/SmokeHTTPClient/GlobalDispatchQueueAsyncResponseInvocationStrategy.swift) is provided as the default, which will execute the completion handler on the Global Dispatch Queue. 
  *  [SameThreadAsyncResponseInvocationStrategy](https://github.com/amzn/smoke-http/blob/master/Sources/SmokeHTTPClient/SameThreadAsyncResponseInvocationStrategy.swift) is also provided which will execute the completion handler on the SwiftNIO callback thread within the client's event loop.
7. **invocationContext**: An instance of type `HTTPClientInvocationContext`.
8. **retryConfiguration**: An instance of type `HTTPClientRetryConfiguration` to indicate how the client should handle automatic retries on failure.
9. . **retryOnError**: A closure of type `(HTTPClientError) -> Bool` that can be used to determine if an automatic retry should occur when the request failures with the provided error.

The complete list of variants for the `HTTPOperationsClient.execute*` functions are:
1. `executeAsyncRetriableWithOutput`: Executes a HTTP request **asynchronously with** built-in support for automatic retries that **produces** an output.
2. `executeAsyncRetriableWithoutOutput`: Executes a HTTP request **synchronously with** built-in support for automatic retries that **doesn't produce** an output.
3. `executeAsyncWithoutOutput`: Executes a HTTP request **asynchronously without** built-in support for automatic retries that **doesn't produce** an output.
4. `executeAsyncWithOutput`: Executes a HTTP request **asynchronously without** built-in support for automatic retries that **produces** an output.
5. `executeSyncRetriableWithoutOutput`: Executes a HTTP request **synchronously with** built-in support for automatic retries that **doesn't produce** an output.
6. `executeSyncRetriableWithOutput`: Executes a HTTP request **synchronously with** built-in support for automatic retries that **produces** an output.
7. `executeSyncWithoutOutput`: Executes a HTTP request **synchronously without** built-in support for automatic retries that **doesn't produce** an output.
8. `executeSyncWithOutput`: Executes a HTTP request **synchronously without** built-in support for automatic retries that **produces** an output.

# Important Protocols and Types

## HTTPClientDelegate

The `HTTPClientDelegate` protocol provides a number extension points that can be used to customise a client.

Protocol function requirements:
1. `getResponseError`: determines the client-specific error based on the HTTP response from the client.
2. `encodeInputAndQueryString`: determines the components to be used for the HTTP request based on the input to an invocation.
3. `decodeOutput` creates an instance of an output type based on the HTTP response from the client.
4. `getTLSConfiguration`: retrieves the TLS configuration to be used by the client.

## HTTPClientInvocationDelegate

The `HTTPClientDelegate` protocol provides a number extension points that can be used to customise the invocation of a client.

Protocol property requirements:
1. `specifyContentHeadersForZeroLengthBody`: If the `Content-Length` and `Content-Type` headers should be sent in the request even when there is no request body.

Protocol function requirements:
1. `addClientSpecificHeaders`: determines any additional headers to be added to HTTP request.
2. `handleErrorResponses`: determines the client-specific error based on the HTTP response from the client. Overrides `HTTPClientDelegate.getResponseError` if a non-nil error is returned.

## HTTPRequestInputProtocol

The `HTTPRequestInputProtocol` provides a mechanism used to transform an input into the different parts of a HTTP request. For an example of how this protocol is used to deconstruct an input type into a HTTP request see [JSONAWSHttpClientDelegate.encodeInputAndQueryString()](https://github.com/amzn/smoke-aws/blob/master/Sources/SmokeAWSHttp/JSONAWSHttpClientDelegate.swift#L57).

Protocol property requirements:
1. `queryEncodable`: Optionally, provides an instance of a type conforming to `Encodable` that will be used to produce the query for the HTTP request.
2. `pathEncodable`: Optionally, provides an instance of a type conforming to `Encodable` that will be used to provide any tokenized values for the path of the HTTP request.
3. `bodyEncodable`: Optionally, provides an instance of a type conforming to `Encodable` that will be used to produce the body for the HTTP request.
4. `additionalHeadersEncodable`: Optionally, provides an instance of a type conforming to `Encodable` that will be used to produce additional headers for the HTTP request.
5. `pathPostfix`: Optionally, provides a string that will be post-pended to the path template prior to having any tokens replaced by values from `pathEncodable`.

## HTTPResponseOutputProtocol

The `HTTPResponseOutputProtocol` provides a mechanism to construct an output type from the components of a HTTP response. For an example of how this is achieved see [JSONAWSHttpClientDelegate.decodeOutput()](https://github.com/amzn/smoke-aws/blob/master/Sources/SmokeAWSHttp/JSONAWSHttpClientDelegate.swift#L129).

Protocol function requirements:
1. `compose`: A function that accepts `bodyDecodableProvider` and `headersDecodableProvider` closures that can be used to construct parts of the expected output type from parts of the HTTP response.

## HTTPClientInvocationContext

The `HTTPClientInvocationContext` type can be used to customise the invocation of a client.

The inputs to the `HTTPClientInvocationContext` constructor are:
1. `reporting`: An instance of a type conforming to the `HTTPClientInvocationReporting` protocol.
2. `handlerDelegate`: An instance of a type conforming to the `HTTPClientInvocationDelegate` protocol.

## HTTPClientInvocationReporting

The `HTTPClientInvocationReporting` protocol provides a number of extension points focused on the reporting of a client invocation-

Protocol property requirements:
1. `logger`: The logger to use for statements related to the HTTP client invocation.
2. `internalRequestId`: the internal identity of the request that is making the invocation to the client.
3. `traceContext`: An instance of a type conforming to the `InvocationTraceContext` protocol.
4. `successCounter`: Optionally, a `Metrics.Counter` that will record successful invocations of the client.
5. `failure5XXCounter`: Optionally, a `Metrics.Counter` that will record unsuccessful invocations of the client that return with a 5xx response code.
6. `failure4XXCounter`: Optionally, a `Metrics.Counter` that will record unsuccessful invocations of the client that return with a 4xx response code.
7. `retryCountRecorder`: Optionally, a `Metrics.Recorder` that will record the retry count for invocations of the client.
8. `latencyTimer`: Optionally, a `Metrics.Recorder` that will record the latency of invocations from the client.

## InvocationTraceContext

The `InvocationTraceContext` provides an extension point for request-level tracing.

Protocol function requirements:
1. `handleOutwardsRequestStart`: Provides the ability to handle an invocation of the client just prior to the request being sent, including the ability to modify the headers sent in the request.
2. `handleOutwardsRequestSuccess`: Provides the ability to handle a successful invocation just after the response has been received.
3. `handleOutwardsRequestFailure`: Provides the ability to handle a unsuccessful invocation just after the response has been received.

# License

This library is licensed under the Apache 2.0 License.
