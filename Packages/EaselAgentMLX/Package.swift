// swift-tools-version: 6.0
// EaselAgentMLX — on-device inference adapter for the Easel agent harness.
// Kept as its own package so the heavy mlx-swift build (Metal kernels) never
// burdens EaselAgentHarness or ClaudeCodeCore; only the app links this.

import PackageDescription

let package = Package(
  name: "EaselAgentMLX",
  platforms: [
    .macOS("14.0")
  ],
  products: [
    .library(
      name: "EaselAgentMLX",
      targets: ["AgentProviderMLX"]
    )
  ],
  dependencies: [
    .package(path: "../EaselAgentHarness"),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "3.31.4"),
    .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0"),
    .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
  ],
  targets: [
    .target(
      name: "AgentProviderMLX",
      dependencies: [
        .product(name: "EaselAgentHarness", package: "EaselAgentHarness"),
        .product(name: "MLXLLM", package: "mlx-swift-lm"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
        .product(name: "HuggingFace", package: "swift-huggingface"),
        .product(name: "Hub", package: "swift-transformers"),
        .product(name: "Tokenizers", package: "swift-transformers"),
      ]
    ),
    .testTarget(
      name: "AgentProviderMLXTests",
      dependencies: ["AgentProviderMLX"]
    ),
  ]
)
