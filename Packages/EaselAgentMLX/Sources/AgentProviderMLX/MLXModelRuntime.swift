import AgentHarness
import Foundation
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Owns the loaded model container across sends (loading weights is
/// expensive) and serializes inference. Create ONE per app and share it with
/// every `MLXModelClient` through the client factory — it is the process-wide
/// GPU tenant, injected rather than accessed as a global.
public actor MLXModelRuntime {

  private let manager: MLXModelManager
  private var loadedRepoId: String?
  private var loadedContainer: ModelContainer?

  public init(manager: MLXModelManager, gpuCacheLimitBytes: Int = 512 * 1_024 * 1_024) {
    self.manager = manager
    MLX.Memory.cacheLimit = gpuCacheLimitBytes
  }

  /// Loads (or reuses) the container for a repo. Only one model stays
  /// resident: requesting a different one evicts the previous container.
  func container(forRepoId repoId: String) async throws -> ModelContainer {
    if loadedRepoId == repoId, let loadedContainer {
      return loadedContainer
    }
    guard await manager.isInstalled(repoId: repoId) else {
      throw AgentHarnessError.modelNotFound(
        "\(repoId) is not downloaded. Download it in Settings → Local / API → On-Device Models."
      )
    }
    // Evict the previous model before loading the next one.
    loadedContainer = nil
    loadedRepoId = nil
    MLX.Memory.clearCache()

    // Weights were already downloaded by MLXModelManager, so load straight
    // from the local directory; only the tokenizer integration is external.
    let container = try await LLMModelFactory.shared.loadContainer(
      from: manager.directory(forRepoId: repoId),
      using: #huggingFaceTokenizerLoader()
    )
    loadedContainer = container
    loadedRepoId = repoId
    return container
  }

  public func unload() {
    loadedContainer = nil
    loadedRepoId = nil
    MLX.Memory.clearCache()
  }
}
