// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselPreview",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselPreview",
      targets: ["EaselPreview"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselKit"),
    .package(
      url: "https://github.com/jamesrochabrun/Canvas",
      branch: "agent/improve-tweaks-workflow"
    ),
  ],
  targets: [
    .target(
      name: "EaselPreview",
      dependencies: [
        "EaselKit",
        .product(name: "Canvas", package: "Canvas"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselPreviewTests",
      dependencies: ["EaselPreview", "EaselKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
