// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AudioWaveLib",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)
    ],
    products: [
        .library(
            name: "AudioWaveLib",
            targets: ["AudioWaveLib"]
        ),
        .executable(
            name: "AudioWaveLibSample",
            targets: ["AudioWaveLibSample"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AudioWaveLib",
            dependencies: []
        ),
        .executableTarget(
            name: "AudioWaveLibSample",
            dependencies: ["AudioWaveLib"],
            path: "Examples/AudioWaveLibSample",
            exclude: ["../../file.mp3"],
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "AudioWaveLibTests",
            dependencies: ["AudioWaveLib"]
        )
    ]
)
