<p align="center">
<a href="https://travis-ci.com/amzn/smoke-http">
<img src="https://travis-ci.com/amzn/smoke-http.svg?branch=master" alt="Build - Master Branch">
</a>
<img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
<a href="http://swift.org">
<img src="https://img.shields.io/badge/swift-5.0-orange.svg?style=flat" alt="Swift 5.0 Compatible">
</a>
<a href="https://gitter.im/SmokeServerSide">
<img src="https://img.shields.io/badge/chat-on%20gitter-ee115e.svg?style=flat" alt="Join the Smoke Server Side community on gitter">
</a>
<img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
</p>

# SmokeHTTP

SmokeHTTP contains the library SmokeHTTPClient which will allow someone building a specific client that requires unique use-cases for HTTP parameters to utilize a generic HTTPClient that allows the user to implement their own delegates that handles client-specific HTTP logic.

The benefit of this package is to consolidate all HTTPClient logic into one location, while other clients  are built to utilize this client while defining their own specific delegates.

## SmokeHTTPClient

To use SmokeHTTPClient, a user can instantiate an ```HTTPClient``` in the constructor of their specific client with instantiated delegates (```HTTPClientDelegate```, ```HTTPClientChannelInboundHandlerDelegate```) that are defined by the client-specific logic.

# Getting Started

## Step 1: Add the SmokeHTTP dependency

SmokeHTTP uses the Swift Package Manager. To use the framework, add the following dependency
to your Package.swift-

```swift
dependencies: [
    .package(url: "https://github.com/amzn/smoke-http.git", from: "1.0.0")
]

.target(
    name: ...,
    dependencies: [..., "SmokeHTTPClient"]),
```

## Step 2: Construct a HTTPClient

Construct a HTTPClient using the following code-

```swift
import SmokeHTTPClient

let httpClient = HTTPClient(endpointHostName: endpointHostName,
                            endpointPort: endpointPort,
                            contentType: contentType,
                            clientDelegate: clientDelegate,
                            connectionTimeoutSeconds: connectionTimeoutSeconds)
```

where ```clientDelegate``` conforms to the ```HTTPClientDelegate``` protocol.

## License

This library is licensed under the Apache 2.0 License.
