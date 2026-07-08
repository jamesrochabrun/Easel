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
    // Revision pin onto Canvas's background-tweaks-status branch; swap to
    // exact: "1.4.0" once that release is tagged.
    .package(url: "https://github.com/jamesrochabrun/Canvas", revision: "62c3cce56fedda4e75f2f5c4d07a165b6eaeba33"),
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
