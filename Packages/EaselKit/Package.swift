// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselKit",
      targets: ["EaselKit"]
    ),
  ],
  targets: [
    .target(
      name: "EaselKit",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselKitTests",
      dependencies: ["EaselKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
