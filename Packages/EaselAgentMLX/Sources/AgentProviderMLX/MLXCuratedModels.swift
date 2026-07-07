import AgentHarness
import Foundation

/// A model Easel recommends for on-device agentic coding.
public struct MLXCuratedModel: Sendable, Identifiable, Equatable {
  /// Hugging Face repo id, e.g. "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit".
  public let id: String
  public let displayName: String
  /// Approximate download size in bytes (directional, shown in UI).
  public let approximateSizeBytes: Int64
  public let minimumTier: MLXAvailability.ModelSizeTier
  public let contextLength: Int
  public let notes: String

  public var modelInfo: AgentModelInfo {
    AgentModelInfo(id: id, displayName: displayName, contextLength: contextLength)
  }
}

/// Starter list, biased toward models with a strong tool-calling track record
/// at 4-bit quantization. Parameter count ≠ tool-calling reliability — these
/// are picked for agentic behavior, not size.
public enum MLXCuratedModels {
  public static let all: [MLXCuratedModel] = [
    MLXCuratedModel(
      id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
      displayName: "Qwen2.5 Coder 7B (4-bit)",
      approximateSizeBytes: 4_300_000_000,
      minimumTier: .medium,
      contextLength: 32_768,
      notes: "Best starting point for agentic coding on 16–32 GB Macs."
    ),
    MLXCuratedModel(
      id: "mlx-community/Qwen2.5-Coder-14B-Instruct-4bit",
      displayName: "Qwen2.5 Coder 14B (4-bit)",
      approximateSizeBytes: 8_300_000_000,
      minimumTier: .large,
      contextLength: 32_768,
      notes: "Stronger coding and tool use; needs 32 GB+ unified memory."
    ),
    MLXCuratedModel(
      id: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit",
      displayName: "Qwen2.5 Coder 3B (4-bit)",
      approximateSizeBytes: 1_900_000_000,
      minimumTier: .small,
      contextLength: 32_768,
      notes: "Lightweight option for 8–16 GB Macs; keep tasks small."
    ),
    MLXCuratedModel(
      id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
      displayName: "Llama 3.2 3B (4-bit)",
      approximateSizeBytes: 1_800_000_000,
      minimumTier: .small,
      contextLength: 32_768,
      notes: "General-purpose small model with function calling."
    ),
  ]

  public static func recommended(for tier: MLXAvailability.ModelSizeTier) -> [MLXCuratedModel] {
    all.filter { $0.minimumTier <= tier }
  }
}
