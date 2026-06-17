// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.processor",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.processor",
            targets: [
                "com.awareframework.ios.sensor.processor"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.processor",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core")
            ],
            path: "Sources/com.awareframework.ios.sensor.processor"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.processorTests",
            dependencies: ["com.awareframework.ios.core", "com.awareframework.ios.sensor.processor"]
        )
    ],
    swiftLanguageModes: [.v5]
)
