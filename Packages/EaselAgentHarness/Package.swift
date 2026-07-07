// swift-tools-version: 6.0
// EaselAgentHarness — UI-free agentic harness for raw LLM API providers.
// Designed for later extraction as a standalone open-source package:
// keep this package free of Easel-specific and UI dependencies.

import PackageDescription

let package = Package(
  name: "EaselAgentHarness",
  platforms: [
    .macOS("14.0")
  ],
  products: [
    .library(
      name: "EaselAgentHarness",
      targets: [
        "AgentHarness",
        "AgentTools",
        "AgentProviderOpenAI",
        "AgentProviderOllama",
      ]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/jamesrochabrun/SwiftOpenAI", from: "4.4.9"),
  ],
  targets: [
    // Core contracts + agent loop. Zero dependencies.
    .target(
      name: "AgentHarness"
    ),
    // Built-in workspace tools (Bash/Read/Write/Edit/Glob/Grep/LS).
    .target(
      name: "AgentTools",
      dependencies: ["AgentHarness"]
    ),
    // OpenAI-compatible adapter (LM Studio, llama.cpp, OpenRouter, Groq, DeepSeek, xAI…).
    // The only target that links SwiftOpenAI.
    .target(
      name: "AgentProviderOpenAI",
      dependencies: [
        "AgentHarness",
        .product(name: "SwiftOpenAI", package: "SwiftOpenAI"),
      ]
    ),
    // Native Ollama /api/chat NDJSON client. Zero external dependencies.
    .target(
      name: "AgentProviderOllama",
      dependencies: ["AgentHarness"]
    ),

    .testTarget(
      name: "AgentHarnessTests",
      dependencies: ["AgentHarness"]
    ),
    .testTarget(
      name: "AgentToolsTests",
      dependencies: ["AgentTools"]
    ),
    .testTarget(
      name: "AgentProviderOllamaTests",
      dependencies: ["AgentProviderOllama"]
    ),
  ]
)
