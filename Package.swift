// swift-tools-version:5.2
//
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

import PackageDescription

let swiftSettings: [SwiftSetting]
#if compiler(<5.6)
swiftSettings = []
#else
swiftSettings = [.unsafeFlags(["-warn-concurrency"])]
#endif

let package = Package(
    name: "smoke-http",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
        ],
    products: [
        .library(
            name: "SmokeHTTPClient",
            targets: ["SmokeHTTPClient"]),
        .library(
            name: "_SmokeHTTPClientConcurrency",
            targets: ["_SmokeHTTPClientConcurrency"]),
        .library(
            name: "QueryCoding",
            targets: ["QueryCoding"]),
        .library(
            name: "HTTPHeadersCoding",
            targets: ["HTTPHeadersCoding"]),
        .library(
            name: "HTTPPathCoding",
            targets: ["HTTPPathCoding"]),
        .library(
            name: "ShapeCoding",
            targets: ["ShapeCoding"]),
        .library(
            name: "SmokeHTTPClientMiddleware",
            targets: ["SmokeHTTPClientMiddleware"]),
        .library(
            name: "SmokeHTTPTypes",
            targets: ["SmokeHTTPTypes"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.14.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/tachyonics/async-http-client.git", .branch("request_body_known_length")),
        .package(url: "https://github.com/tachyonics/swift-http-client-middleware", .branch("poc")),
        .package(url: "https://github.com/tachyonics/async-http-middleware-client", .branch("poc"))
    ],
    targets: [
        .target(
            name: "SmokeHTTPClient", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "StandardHttpClientMiddleware", package: "swift-http-client-middleware"),
                .target(name: "SmokeHTTPTypes"),
            ]),
        .target(
            name: "_SmokeHTTPClientConcurrency", dependencies: [
                .target(name: "SmokeHTTPClient"),
            ]),
        .target(
            name: "QueryCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HTTPHeadersCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HTTPPathCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "ShapeCoding", dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmokeHTTPClientMiddleware", dependencies: [
                .product(name: "HttpClientMiddleware", package: "swift-http-client-middleware"),
                .product(name: "StandardHttpClientMiddleware", package: "swift-http-client-middleware"),
                .product(name: "AsyncHttpMiddlewareClient", package: "async-http-middleware-client"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .target(name: "SmokeHTTPTypes"),
                .target(name: "HTTPHeadersCoding"),
                .target(name: "HTTPPathCoding"),
                .target(name: "QueryCoding")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmokeHTTPTypes", dependencies: [
                .product(name: "Metrics", package: "swift-metrics"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SmokeHTTPClientTests", dependencies: [
                .target(name: "SmokeHTTPClient"),
            ]),
        .testTarget(
            name: "ShapeCodingTests", dependencies: [
                .target(name: "ShapeCoding"),
            ]),
        .testTarget(
            name: "QueryCodingTests", dependencies: [
                .target(name: "QueryCoding"),
            ]),
        .testTarget(
            name: "HTTPHeadersCodingTests", dependencies: [
                .target(name: "HTTPHeadersCoding"),
            ]),
        .testTarget(
            name: "HTTPPathCodingTests", dependencies: [
                .target(name: "HTTPPathCoding"),
            ]),
    ]
)
