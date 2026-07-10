// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselWebInspector",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselWebInspector",
      targets: ["EaselWebInspector"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselKit"),
    .package(
      url: "https://github.com/jamesrochabrun/Canvas",
      revision: "72fc33e6b7de4626f387b46dd2e2fdaeb89b1c07"
    ),
  ],
  targets: [
    .target(
      name: "EaselWebInspector",
      dependencies: [
        "EaselKit",
        .product(name: "Canvas", package: "Canvas"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselWebInspectorTests",
      dependencies: ["EaselWebInspector", "EaselKit"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
