// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "background_downloader", path: "../.packages/background_downloader-9.6.4"),
        .package(name: "connectivity_plus", path: "../.packages/connectivity_plus-7.3.2"),
        .package(name: "flutter_edge_ai", path: "../.packages/flutter_edge_ai-2.3.2"),
        .package(name: "large_file_handler", path: "../.packages/large_file_handler-0.5.2"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.7"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "background-downloader", package: "background_downloader"),
                .product(name: "connectivity-plus", package: "connectivity_plus"),
                .product(name: "flutter-edge-ai", package: "flutter_edge_ai"),
                .product(name: "large-file-handler", package: "large_file_handler"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
