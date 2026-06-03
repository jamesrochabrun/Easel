// swift-tools-version: 5.5

import PackageDescription

let package = Package(
  name: "CodeEditSymbols",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .library(
      name: "CodeEditSymbols",
      targets: ["CodeEditSymbols"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "CodeEditSymbols",
      dependencies: [],
      resources: [
        .process("Symbols.xcassets")
      ]
    ),
  ]
)
