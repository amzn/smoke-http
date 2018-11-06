// swift-tools-version:4.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SmokeHTTP",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SmokeHTTPClient",
            targets: ["SmokeHTTPClient"]),
        .library(
            name: "QueryCoder",
            targets: ["QueryCoder"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "1.0.0"),
        .package(url: "https://github.com/IBM-Swift/LoggerAPI.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SmokeHTTPClient",
            dependencies: ["LoggerAPI", "NIO", "NIOHTTP1", "NIOOpenSSL"]),
        .target(
            name: "QueryCoder",
            dependencies: ["LoggerAPI"]),
        .testTarget(
            name: "SmokeHTTPClientTests",
            dependencies: ["SmokeHTTPClient"]),
        .testTarget(
            name: "QueryCoderTests",
            dependencies: ["QueryCoder"]),
    ]
)
