// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselChat",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselDesignSystems",
      targets: ["EaselDesignSystems"]
    ),
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
      name: "EaselDesignSystems",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "EaselChat",
      dependencies: [
        "EaselDesignSystems",
        "EaselKit",
        .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
        .product(name: "ClaudeCodeCore", package: "EaselClaudeCodeUI"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselDesignSystemsTests",
      dependencies: [
        "EaselDesignSystems",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselChatTests",
      dependencies: [
        "EaselChat",
        "EaselDesignSystems",
        "EaselKit",
        .product(name: "ClaudeCodeCore", package: "EaselClaudeCodeUI"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
