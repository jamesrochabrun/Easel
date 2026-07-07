import Foundation

extension Notification.Name {
  /// Posted when the set of locally-installed models changes (e.g. an
  /// on-device MLX model finished downloading or was deleted). The settings
  /// model picker observes this to refresh immediately.
  public static let agentInstalledModelsDidChange = Notification.Name("agentInstalledModelsDidChange")
}
