// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jornada",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Jornada",
            path: "Sources/Jornada",
            exclude: ["Jornada.entitlements"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JornadaTests",
            dependencies: [
                "Jornada",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/JornadaTests"
        )
    ]
)
