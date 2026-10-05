// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EaselMCPServer",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "EaselMCPServer",
      targets: ["EaselMCPServer"]
    ),
  ],
  dependencies: [
    .package(path: "../EaselStudio"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
  ],
  targets: [
    .executableTarget(
      name: "EaselMCPServer",
      dependencies: [
        .product(name: "EaselStudioCore", package: "EaselStudio"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "EaselMCPServerTests",
      dependencies: ["EaselMCPServer"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
