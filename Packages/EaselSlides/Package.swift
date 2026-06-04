// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselSlides",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "EaselSlides",
      targets: ["EaselSlides"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselKit"),
  ],
  targets: [
    .target(
      name: "EaselSlides",
      dependencies: [
        "EaselKit",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselSlidesTests",
      dependencies: [
        "EaselSlides",
        "EaselKit",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
