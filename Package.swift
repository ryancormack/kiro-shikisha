// swift-tools-version: 6.0

import PackageDescription

#if os(macOS)
let linkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/KiroShikisha/Info.plist"])
]
#else
let linkerSettings: [LinkerSetting] = []
#endif

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
            linkerSettings: linkerSettings
        ),
        .testTarget(
            name: "KiroShikishaTests",
            dependencies: ["KiroShikisha"],
            path: "Tests/KiroShikishaTests"
        )
    ]
)
