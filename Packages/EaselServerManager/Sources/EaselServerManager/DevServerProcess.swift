//
//  DevServerProcess.swift
//  EaselServerManager
//

import Foundation
import OSLog

private let processLog = Logger(
  subsystem: "com.easel.servermanager",
  category: "DevServerProcess"
)

enum DevServerError: LocalizedError {
  case noPackageJSON
  case noDevScript
  case processExitedBeforeURL(code: Int32, stderr: String)
  case urlDetectionTimeout
  case alreadyRunning

  var errorDescription: String? {
    switch self {
    case .noPackageJSON:
      return "No package.json found in working directory"
    case .noDevScript:
      return "No 'dev' script found in package.json"
    case .processExitedBeforeURL(let code, let stderr):
      return "Dev server exited with code \(code): \(stderr)"
    case .urlDetectionTimeout:
      return "Timed out waiting for dev server URL"
    case .alreadyRunning:
      return "Dev server is already running"
    }
  }
}

@MainActor
final class DevServerProcess {

  let workingDirectory: String
  private var process: Process?
  private var stdoutPipe: Pipe?
  private var stderrPipe: Pipe?
  private(set) var detectedURL: URL?
  private var stderrBuffer = ""
  private var startContinuation: CheckedContinuation<URL, Error>?

  init(workingDirectory: String) {
    self.workingDirectory = workingDirectory
  }

  // MARK: - Public

  /// Starts the dev server and waits until a localhost URL is detected.
  func start(timeout: TimeInterval = 30) async throws -> URL {
    if process?.isRunning == true {
      throw DevServerError.alreadyRunning
    }

    let devCommand = try detectDevCommand()
    processLog.info("Detected dev command: \(devCommand) in \(self.workingDirectory)")

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        startContinuation = continuation
        stderrBuffer = ""
        detectedURL = nil

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "npm run dev"]
        proc.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardOutput = stdout
        proc.standardError = stderr

        // Monitor stdout for URL
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
          let data = handle.availableData
          guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
          processLog.debug("stdout: \(text)")
          if let url = DevServerURLDetector.extractURL(from: text) {
            processLog.info("Detected URL from stdout: \(url.absoluteString)")
            Task { @MainActor [weak self] in
              self?.detectedURL = url
              self?.resumeStart(with: .success(url))
            }
          }
        }

        // Monitor stderr for URL (some servers print there)
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
          let data = handle.availableData
          guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
          processLog.debug("stderr: \(text)")
          if let url = DevServerURLDetector.extractURL(from: text) {
            processLog.info("Detected URL from stderr: \(url.absoluteString)")
            Task { @MainActor [weak self] in
              self?.stderrBuffer += text
              self?.detectedURL = url
              self?.resumeStart(with: .success(url))
            }
          } else {
            Task { @MainActor [weak self] in
              self?.stderrBuffer += text
            }
          }
        }

        proc.terminationHandler = { [weak self] process in
          processLog.info("Dev server exited with code \(process.terminationStatus)")
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.clearProcess()
            self.resumeStart(
              with: .failure(
                DevServerError.processExitedBeforeURL(
                  code: process.terminationStatus,
                  stderr: self.stderrBuffer
                )
              )
            )
          }
        }

        self.process = proc
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        do {
          try proc.run()
          processLog.info("Dev server process started (PID: \(proc.processIdentifier))")
        } catch {
          processLog.error("Failed to start dev server: \(error.localizedDescription)")
          clearProcess()
          resumeStart(with: .failure(error))
          return
        }

        Task { @MainActor [weak self] in
          try? await Task.sleep(for: .milliseconds(Int64(timeout * 1_000)))
          guard let self, self.startContinuation != nil else { return }
          self.stop()
          self.resumeStart(with: .failure(DevServerError.urlDetectionTimeout))
        }
      }
    } onCancel: {
      Task { @MainActor [weak self] in
        self?.stop()
        self?.resumeStart(with: .failure(CancellationError()))
      }
    }
  }

  /// Sends SIGTERM to the dev server process.
  func stop() {
    guard let proc = process, proc.isRunning else {
      clearProcess()
      return
    }

    processLog.info("Stopping dev server (PID: \(proc.processIdentifier))")

    clearProcess()
    proc.terminate()
  }

  var isRunning: Bool {
    process?.isRunning ?? false
  }

  // MARK: - Private

  private func resumeStart(with result: Result<URL, Error>) {
    guard let continuation = startContinuation else { return }
    startContinuation = nil
    continuation.resume(with: result)
  }

  private func clearProcess() {
    stdoutPipe?.fileHandleForReading.readabilityHandler = nil
    stderrPipe?.fileHandleForReading.readabilityHandler = nil
    stdoutPipe = nil
    stderrPipe = nil
    process = nil
    detectedURL = nil
  }

  private func detectDevCommand() throws -> String {
    let packagePath = (workingDirectory as NSString)
      .appendingPathComponent("package.json")

    guard FileManager.default.fileExists(atPath: packagePath) else {
      throw DevServerError.noPackageJSON
    }

    guard let data = FileManager.default.contents(atPath: packagePath),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let scripts = json["scripts"] as? [String: Any],
      let devScript = scripts["dev"] as? String
    else {
      throw DevServerError.noDevScript
    }

    return devScript
  }
}
