// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselServerManager",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselServerManager",
      targets: ["EaselServerManager"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselKit"),
  ],
  targets: [
    .target(
      name: "EaselServerManager",
      dependencies: ["EaselKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselServerManagerTests",
      dependencies: ["EaselServerManager", "EaselKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
