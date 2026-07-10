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
      revision: "980e222ef5a42c6b54e202fe29f942cd784dc078"
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
