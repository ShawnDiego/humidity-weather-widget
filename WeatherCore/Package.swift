// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherCore",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0")
    ],
    products: [
        .library(name: "WeatherCore", targets: ["WeatherCore"]),
        .executable(name: "WeatherMonitor", targets: ["WeatherMonitor"])
    ],
    targets: [
        .target(
            name: "WeatherCore"
        ),
        .executableTarget(
            name: "WeatherMonitor",
            dependencies: ["WeatherCore"],
            path: "Sources/WeatherMonitor"
        ),
        .testTarget(
            name: "WeatherCoreTests",
            dependencies: ["WeatherCore"]
        )
    ]
)
