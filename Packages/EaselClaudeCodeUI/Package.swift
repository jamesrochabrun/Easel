// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EaselClaudeCodeUI",
    platforms: [
        .macOS("14.0")
    ],
    products: [
        // Library for developers to use in their own apps
        .library(
            name: "ClaudeCodeCore",
            targets: ["ClaudeCodeCore"]
        )
    ],
    dependencies: [
        // External dependencies
        .package(url: "https://github.com/jamesrochabrun/PierreDiffsSwift", exact: "1.1.3"),
        .package(url: "https://github.com/jamesrochabrun/ClaudeCodeSDK", exact: "1.2.4"),
        .package(url: "https://github.com/jamesrochabrun/CodexSDK.git", exact: "1.0.6"),
        .package(path: "../EaselKit"),
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic", exact: "2.2.0"),
        .package(url: "https://github.com/appstefan/highlightswift", from: "1.1.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.9.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
    ],
    targets: [
        .target(
            name: "CCCustomPermissionServiceInterface",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")
            ],
            path: "Sources/CustomPermissionServiceInterface"
        ),
        .target(
            name: "CCTerminalServiceInterface",
            path: "Sources/TerminalServiceInterface"
        ),
        
        // Modules with single dependencies
        .target(
            name: "CCTerminalService",
            dependencies: ["CCTerminalServiceInterface"],
            path: "Sources/TerminalService"
        ),
        .target(
            name: "CCCustomPermissionService",
            dependencies: [
                "CCCustomPermissionServiceInterface",
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/CustomPermissionService"
        ),
        
        // Core library containing all reusable components
        .target(
            name: "ClaudeCodeCore",
            dependencies: [
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
                .product(name: "CodexSDK", package: "CodexSDK"),
                .product(name: "EaselKit", package: "EaselKit"),
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                .product(name: "HighlightSwift", package: "highlightswift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "PierreDiffsSwift", package: "PierreDiffsSwift"),

                // Internal module dependencies
                "CCCustomPermissionService",
                "CCCustomPermissionServiceInterface",
                "CCTerminalService",
                "CCTerminalServiceInterface",
            ],
            path: "Sources/ClaudeCodeCore",
            exclude: [
                "FileSearch/FileSearch_README.md",
                "ClaudeCodeUI.entitlements"
            ],
            resources: [
                .process("Assets.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

        // Test targets
        .testTarget(
            name: "ClaudeCodeCoreTests",
            dependencies: [
                "ClaudeCodeCore",
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
                .product(name: "CodexSDK", package: "CodexSDK"),
            ],
            path: "Tests/ClaudeCodeCoreTests"
        ),
    ]
)
