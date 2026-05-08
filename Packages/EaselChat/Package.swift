// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselChat",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselChat",
      targets: ["EaselChat"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselKit"),
    .package(path: "../../../ClaudeCodeSDK"),
    .package(path: "../EaselClaudeCodeUI"),
  ],
  targets: [
    .target(
      name: "EaselChat",
      dependencies: [
        "EaselKit",
        .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
        .product(name: "ClaudeCodeCore", package: "EaselClaudeCodeUI"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselChatTests",
      dependencies: [
        "EaselChat",
        "EaselKit",
        .product(name: "ClaudeCodeCore", package: "EaselClaudeCodeUI"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
