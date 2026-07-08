import Foundation

/// Fatal, loop-terminating errors. Tool-level failures never surface here —
/// they are returned to the model as `ToolResult(isError: true)`.
public enum AgentHarnessError: Error, LocalizedError, Sendable, Equatable {
  case network(String)
  case httpStatus(code: Int, body: String?)
  case authenticationRequired
  case modelNotFound(String)
  case streamTimeout(seconds: Int)
  case malformedResponse(String)
  case maxTurnsExceeded(Int)
  case contextWindowExceeded(estimated: Int, limit: Int)
  case cancelled

  public var errorDescription: String? {
    switch self {
    case .network(let detail):
      return "Could not reach the model endpoint: \(detail)"
    case .httpStatus(let code, _) where code == 401 || code == 403:
      return "The endpoint rejected the request (\(code)). Check your API key in Settings."
    case .httpStatus(let code, let body):
      return "The endpoint returned HTTP \(code)\(body.map { ": \($0)" } ?? "")"
    case .authenticationRequired:
      return "This endpoint requires an API key. Add one in Settings."
    case .modelNotFound(let model):
      return "Model \"\(model)\" was not found on the endpoint."
    case .streamTimeout(let seconds):
      return "No data received from the model for \(seconds) seconds."
    case .malformedResponse(let detail):
      return "The endpoint returned an unexpected response: \(detail)"
    case .maxTurnsExceeded(let turns):
      return "Stopped after \(turns) tool-use turns without a final answer."
    case .contextWindowExceeded(let estimated, let limit):
      return "The conversation (~\(estimated) tokens) no longer fits the model's context window (\(limit) tokens)."
    case .cancelled:
      return "The request was cancelled."
    }
  }
}
