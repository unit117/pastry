// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PastryArchitect",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "PastryArchitect", targets: ["PastryArchitect"])
    ],
    targets: [
        .executableTarget(
            name: "PastryArchitect",
            path: "PastryArchitect"
        ),
        .testTarget(
            name: "PastryArchitectTests",
            dependencies: ["PastryArchitect"],
            path: "Tests/PastryArchitectTests"
        )
    ]
)
