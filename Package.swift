// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-xml",
    products: [
        .library(
            name: "swiftXml",
            targets: ["swiftXml"]
        ),
    ],
    targets: [
        .target(
            name: "swiftXml"
        ),
        .testTarget(
            name: "swiftXmlTests",
            dependencies: ["swiftXml"]
        ),
    ]
)
