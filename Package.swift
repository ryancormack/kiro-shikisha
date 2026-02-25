// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KiroShikisha",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "KiroShikisha",
            path: "Sources/KiroShikisha"
        ),
        .testTarget(
            name: "KiroShikishaTests",
            dependencies: ["KiroShikisha"],
            path: "Tests/KiroShikishaTests"
        )
    ]
)
