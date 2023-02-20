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

let package = Package(
    name: "smoke-http",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13)
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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/awslabs/smithy-swift", .exact("0.12.0"))
    ],
    targets: [
        .target(
            name: "SmokeHTTPClient", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "ClientRuntime", package: "smithy-swift"),
            ]),
        .target(
            name: "_SmokeHTTPClientConcurrency", dependencies: [
                .target(name: "SmokeHTTPClient"),
            ]),
        .target(
            name: "QueryCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ]),
        .target(
            name: "HTTPHeadersCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ]),
        .target(
            name: "HTTPPathCoding", dependencies: [
                .target(name: "ShapeCoding"),
            ]),
        .target(
            name: "ShapeCoding", dependencies: [
                .product(name: "Logging", package: "swift-log"),
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
