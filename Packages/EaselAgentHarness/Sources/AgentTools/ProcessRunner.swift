import Foundation

/// Result of running a subprocess to completion.
struct ProcessRunResult: Sendable {
  var standardOutput: String
  var standardError: String
  var exitCode: Int32
  var timedOut: Bool

  /// stdout followed by stderr, separated by a newline when both are present.
  var combinedOutput: String {
    switch (standardOutput.isEmpty, standardError.isEmpty) {
    case (false, false):
      return standardOutput + (standardOutput.hasSuffix("\n") ? "" : "\n") + standardError
    case (false, true):
      return standardOutput
    case (true, false):
      return standardError
    case (true, true):
      return ""
    }
  }
}

/// Shared subprocess runner used by `BashTool` and `GrepTool`.
///
/// Uses only structured concurrency: termination is awaited through
/// `Process.terminationHandler` bridged to a continuation, and both pipes are
/// drained concurrently (so a chatty command can never deadlock on a full
/// pipe). On timeout or task cancellation the process receives SIGTERM,
/// followed by SIGKILL after a 2-second grace period.
enum ProcessRunner {

  /// Thread-safe one-shot signal used to bridge `terminationHandler` to
  /// async/await. Safe to signal before or after `wait()` starts.
  private final class TerminationSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var isSignaled = false
    private var continuation: CheckedContinuation<Void, Never>?

    var wasSignaled: Bool {
      lock.lock()
      defer { lock.unlock() }
      return isSignaled
    }

    func signal() {
      lock.lock()
      isSignaled = true
      let pending = continuation
      continuation = nil
      lock.unlock()
      pending?.resume()
    }

    func wait() async {
      await withCheckedContinuation { newContinuation in
        lock.lock()
        if isSignaled {
          lock.unlock()
          newContinuation.resume()
        } else {
          continuation = newContinuation
          lock.unlock()
        }
      }
    }
  }

  private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
      lock.lock()
      value = true
      lock.unlock()
    }

    func get() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      return value
    }
  }

  /// Runs `executable` with `arguments` and waits for it to exit.
  ///
  /// - Parameters:
  ///   - environmentOverrides: merged over the inherited process environment.
  ///   - timeoutMilliseconds: if the process outlives this, it is terminated
  ///     and the result is flagged `timedOut` (partial output is preserved).
  static func run(
    executablePath: String,
    arguments: [String],
    workingDirectory: URL,
    environmentOverrides: [String: String],
    timeoutMilliseconds: Int?
  ) async throws -> ProcessRunResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.currentDirectoryURL = workingDirectory

    var environment = ProcessInfo.processInfo.environment
    for (key, value) in environmentOverrides {
      environment[key] = value
    }
    process.environment = environment

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.standardInput = FileHandle.nullDevice

    let terminationSignal = TerminationSignal()
    process.terminationHandler = { _ in
      terminationSignal.signal()
    }

    try process.run()
    let pid = process.processIdentifier

    // Drain both pipes concurrently so neither can fill up and block the child.
    let stdoutReader = Task { await Self.readToEnd(stdoutPipe.fileHandleForReading) }
    let stderrReader = Task { await Self.readToEnd(stderrPipe.fileHandleForReading) }

    let timedOut = Flag()
    // Watchdog: SIGTERM at the deadline, SIGKILL 2s later if still running.
    let watchdog: Task<Void, Never>? = timeoutMilliseconds.map { milliseconds in
      Task {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
        guard !Task.isCancelled, !terminationSignal.wasSignaled else { return }
        timedOut.set()
        kill(pid, SIGTERM)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard !Task.isCancelled, !terminationSignal.wasSignaled else { return }
        kill(pid, SIGKILL)
      }
    }

    await withTaskCancellationHandler {
      await terminationSignal.wait()
    } onCancel: {
      guard !terminationSignal.wasSignaled else { return }
      kill(pid, SIGTERM)
      Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if !terminationSignal.wasSignaled {
          kill(pid, SIGKILL)
        }
      }
    }
    watchdog?.cancel()

    // The process has exited; readers finish once the pipes hit EOF. If a
    // grandchild inherited the write end and keeps it open, force EOF after a
    // short grace so the tool call still returns.
    let readerGrace = Task {
      try? await Task.sleep(nanoseconds: 2_000_000_000)
      try? stdoutPipe.fileHandleForReading.close()
      try? stderrPipe.fileHandleForReading.close()
    }
    let standardOutput = await stdoutReader.value
    let standardError = await stderrReader.value
    readerGrace.cancel()

    return ProcessRunResult(
      standardOutput: standardOutput,
      standardError: standardError,
      exitCode: process.terminationStatus,
      timedOut: timedOut.get()
    )
  }

  private static func readToEnd(_ handle: FileHandle) async -> String {
    var data = Data()
    do {
      for try await byte in handle.bytes {
        data.append(byte)
      }
    } catch {
      // Reading past a closed handle (reader grace) or transient I/O errors:
      // return whatever was captured so far.
    }
    return String(decoding: data, as: UTF8.self)
  }
}

/// Shared output shaping for tools that can produce unbounded text.
enum ToolOutputFormatting {

  static let defaultHeadCharacters = 20_000
  static let defaultTailCharacters = 8_000

  /// Keeps the first `head` and last `tail` characters, eliding the middle
  /// with an explicit marker so the model knows output was dropped.
  static func truncateMiddle(
    _ text: String,
    head: Int = defaultHeadCharacters,
    tail: Int = defaultTailCharacters
  ) -> String {
    guard text.count > head + tail else { return text }
    let elided = text.count - head - tail
    let headText = text.prefix(head)
    let tailText = text.suffix(tail)
    return "\(headText)\n… [output truncated: \(elided) characters elided] …\n\(tailText)"
  }
}
