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
            path: "Sources/KiroShikisha",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/KiroShikisha/Info.plist"])
            ]
        ),
        .testTarget(
            name: "KiroShikishaTests",
            dependencies: ["KiroShikisha"],
            path: "Tests/KiroShikishaTests"
        )
    ]
)
