// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KreeRequest",
    platforms: [.iOS(.v16), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6), .driverKit(.v19), .macCatalyst(.v13), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "KreeRequest",
            targets: ["KreeRequest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
        .package(url: "https://github.com/fumoboy007/swift-retry.git", from: "0.2.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "KreeRequest",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "DMRetry", package: "swift-retry"),
            ]
        ),
    ]
)
