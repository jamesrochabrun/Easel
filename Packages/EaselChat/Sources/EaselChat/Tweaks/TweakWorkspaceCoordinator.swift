import EaselKit
import Foundation

actor TweakWorkspaceCoordinator: TweakWorkspaceCoordinating {
  private let fileManager: FileManager
  private let temporaryRootURL: URL

  init(
    fileManager: FileManager = .default,
    temporaryRootURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.temporaryRootURL = temporaryRootURL
      ?? fileManager.temporaryDirectory.appendingPathComponent("Easel-Tweaks", isDirectory: true)
  }

  func prepare(targetFileURL: URL) async throws -> TweakWorkspaceTransaction {
    let targetURL = targetFileURL.standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) else {
      throw TweakWorkspaceError.missingTarget
    }
    guard !isDirectory.boolValue else {
      throw TweakWorkspaceError.unsupportedTarget
    }

    let baseContents = try Data(contentsOf: targetURL)
    let rootURL = temporaryRootURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    let workingFileURL = rootURL.appendingPathComponent(targetURL.lastPathComponent)
    try baseContents.write(to: workingFileURL, options: .atomic)

    return TweakWorkspaceTransaction(
      rootURL: rootURL,
      workingFileURL: workingFileURL,
      targetFileURL: targetURL,
      baseContents: baseContents
    )
  }

  func finish(_ transaction: TweakWorkspaceTransaction) async throws -> InspectorTweakResult {
    defer { try? fileManager.removeItem(at: transaction.rootURL) }

    let generatedContents = try Data(contentsOf: transaction.workingFileURL)
    guard generatedContents != transaction.baseContents else {
      return .noChanges
    }

    guard fileManager.fileExists(atPath: transaction.targetFileURL.path) else {
      return .conflict
    }
    let currentContents = try Data(contentsOf: transaction.targetFileURL)
    guard currentContents == transaction.baseContents else {
      return .conflict
    }

    try generatedContents.write(to: transaction.targetFileURL, options: .atomic)
    return .applied
  }

  func discard(_ transaction: TweakWorkspaceTransaction) async {
    try? fileManager.removeItem(at: transaction.rootURL)
  }
}
