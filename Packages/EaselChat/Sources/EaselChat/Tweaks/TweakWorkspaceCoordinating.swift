import EaselKit
import Foundation

protocol TweakWorkspaceCoordinating: Sendable {
  func prepare(targetFileURL: URL) async throws -> TweakWorkspaceTransaction
  func finish(
    _ transaction: TweakWorkspaceTransaction,
    policy: InspectorTweakPolicy
  ) async throws -> InspectorTweakResult
  func discard(_ transaction: TweakWorkspaceTransaction) async
}
