// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jornada",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Jornada",
            path: "Sources/Jornada",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
