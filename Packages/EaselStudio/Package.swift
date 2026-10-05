// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselStudio",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselStudioCore",
      targets: ["EaselStudioCore"]
    ),
    .library(
      name: "EaselStudio",
      targets: ["EaselStudio"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/jamesrochabrun/Canvas", exact: "1.3.4"),
    .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.15.3"),
  ],
  targets: [
    // Zero app dependencies: linked by both the app and the EaselMCPServer
    // binary, so the tool boundary and the app share one implementation of
    // the models, CSS scoper, normalizer, queue, and index.
    .target(
      name: "EaselStudioCore",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselStudioCoreTests",
      dependencies: ["EaselStudioCore"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    // App-side services and UI: library, document writer, static server,
    // queue monitor, prompt builders, and the Designs surface views.
    .target(
      name: "EaselStudio",
      dependencies: [
        "EaselStudioCore",
        .product(name: "Canvas", package: "Canvas"),
        .product(name: "SQLite", package: "SQLite.swift"),
      ],
      resources: [
        .copy("Resources/EaselStudioSkill")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselStudioTests",
      dependencies: ["EaselStudio", "EaselStudioCore"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
