import Foundation

enum TweakWorkspaceError: LocalizedError {
  case missingTarget
  case unsupportedTarget

  var errorDescription: String? {
    switch self {
    case .missingTarget:
      return "The preview file is no longer available."
    case .unsupportedTarget:
      return "Tweaks can only be added to a regular design file."
    }
  }
}
