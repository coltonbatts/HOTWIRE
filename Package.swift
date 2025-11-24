// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Hotwire",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Hotwire",
            targets: ["Hotwire"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Hotwire",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
