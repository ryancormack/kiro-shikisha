// swift-tools-version: 6.0

import PackageDescription

#if os(macOS)
let linkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/KiroKantoku/Info.plist"])
]
#else
let linkerSettings: [LinkerSetting] = []
#endif

let package = Package(
    name: "KiroKantoku",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/aptove/swift-sdk", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "KiroKantoku",
            dependencies: [
                .product(name: "ACPModel", package: "swift-sdk"),
                .product(name: "ACP", package: "swift-sdk")
            ],
            path: "Sources/KiroKantoku",
            exclude: ["Info.plist"],
            linkerSettings: linkerSettings
        ),
        .testTarget(
            name: "KiroKantokuTests",
            dependencies: ["KiroKantoku"],
            path: "Tests/KiroKantokuTests"
        )
    ]
)
