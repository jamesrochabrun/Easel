import Foundation
import Hub

/// Manages on-device model weights: download with progress, list, delete.
///
/// Weights live under Application Support (a re-downloadable cache, not user
/// content), mirroring the Hugging Face hub layout that `HubApi` produces:
/// `<root>/models/<org>/<name>/…`.
public actor MLXModelManager {

  public struct InstalledModel: Sendable, Identifiable, Equatable {
    /// Hub repo id, e.g. "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit".
    public let id: String
    public let sizeBytes: Int64
  }

  public enum DownloadState: Sendable, Equatable {
    case downloading(fraction: Double)
    case finished
    case failed(String)
  }

  private let rootDirectory: URL
  private var activeDownloads: [String: Task<Void, Error>] = [:]

  public static func defaultRootDirectory() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    return base.appendingPathComponent("Easel/Models", isDirectory: true)
  }

  public init(rootDirectory: URL = MLXModelManager.defaultRootDirectory()) {
    self.rootDirectory = rootDirectory
  }

  /// The `HubApi` other components (model loading) must use so cache paths agree.
  public nonisolated var hub: HubApi {
    HubApi(downloadBase: rootDirectory)
  }

  public func directory(forRepoId repoId: String) -> URL {
    rootDirectory.appendingPathComponent("models").appendingPathComponent(repoId)
  }

  /// A model counts as installed once its directory holds safetensor weights.
  public func isInstalled(repoId: String) -> Bool {
    let directory = directory(forRepoId: repoId)
    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
      return false
    }
    return contents.contains { $0.hasSuffix(".safetensors") }
  }

  public func installedModels() -> [InstalledModel] {
    let modelsRoot = rootDirectory.appendingPathComponent("models")
    let fileManager = FileManager.default
    guard let organizations = try? fileManager.contentsOfDirectory(atPath: modelsRoot.path) else {
      return []
    }
    var installed: [InstalledModel] = []
    for organization in organizations where !organization.hasPrefix(".") {
      let organizationURL = modelsRoot.appendingPathComponent(organization)
      guard let names = try? fileManager.contentsOfDirectory(atPath: organizationURL.path) else { continue }
      for name in names where !name.hasPrefix(".") {
        let repoId = "\(organization)/\(name)"
        if isInstalled(repoId: repoId) {
          installed.append(InstalledModel(id: repoId, sizeBytes: diskUsage(repoId: repoId)))
        }
      }
    }
    return installed.sorted { $0.id < $1.id }
  }

  public func diskUsage(repoId: String) -> Int64 {
    let directory = directory(forRepoId: repoId)
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
    ) else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
      let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
      total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }
    return total
  }

  /// Downloads a model snapshot, reporting progress via the callback.
  /// Cancelling the surrounding task cleans up the partial download when the
  /// weights never arrived.
  public func download(
    repoId: String,
    progress: @escaping @Sendable (Double) -> Void
  ) async throws {
    if isInstalled(repoId: repoId) {
      progress(1)
      return
    }
    if let existing = activeDownloads[repoId] {
      try await existing.value
      return
    }

    let hub = self.hub
    let task = Task {
      do {
        _ = try await hub.snapshot(
          from: Hub.Repo(id: repoId),
          matching: ["*.safetensors", "*.json", "*.txt", "tokenizer*", "*.model"]
        ) { hubProgress in
          progress(hubProgress.fractionCompleted)
        }
        progress(1)
      } catch {
        if !self.isInstalled(repoId: repoId) {
          try? FileManager.default.removeItem(at: self.directory(forRepoId: repoId))
        }
        throw error
      }
    }
    activeDownloads[repoId] = task
    defer { activeDownloads[repoId] = nil }
    try await task.value
  }

  public func delete(repoId: String) throws {
    activeDownloads[repoId]?.cancel()
    activeDownloads[repoId] = nil
    let directory = directory(forRepoId: repoId)
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }
}
