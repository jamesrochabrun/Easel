//
//  EaselTerminalView.swift
//  Easel
//
//  Simplified terminal view adapted from AgentHub's EmbeddedTerminalView.
//

import AppKit
import SwiftTerm
import SwiftUI
import os

private let logger = Logger(subsystem: "com.easel", category: "EaselTerminal")

// MARK: - SafeLocalProcessTerminalView

/// A ManagedLocalProcessTerminalView subclass that safely handles cleanup by stopping
/// data reception before process termination. This prevents crashes when the
/// terminal buffer receives data during deallocation.
class SafeLocalProcessTerminalView: ManagedLocalProcessTerminalView {
  private var _isStopped = false
  private let stopLock = NSLock()

  var isStopped: Bool {
    stopLock.lock()
    defer { stopLock.unlock() }
    return _isStopped
  }

  /// Call this BEFORE terminating the process to safely stop data reception.
  func stopReceivingData() {
    stopLock.lock()
    _isStopped = true
    stopLock.unlock()
  }

  override func dataReceived(slice: ArraySlice<UInt8>) {
    guard !isStopped else { return }
    super.dataReceived(slice: slice)
  }
}

// MARK: - EaselTerminalView

/// SwiftUI wrapper for a local-process terminal.
struct EaselTerminalView: NSViewRepresentable {
  @Environment(\.colorScheme) private var colorScheme

  let projectPath: String
  let bridge: TerminalBridge
  var onUserInteraction: (() -> Void)?

  func makeNSView(context: Context) -> EaselTerminalContainerView {
    let isDark = colorScheme == .dark
    let containerView = EaselTerminalContainerView()
    containerView.localhostDetector = bridge.localhostDetector
    containerView.configure(projectPath: projectPath, isDark: isDark)
    containerView.onUserInteraction = onUserInteraction
    bridge.register(containerView)
    return containerView
  }

  func updateNSView(_ nsView: EaselTerminalContainerView, context: Context) {
    nsView.onUserInteraction = onUserInteraction
    nsView.syncAppearance(isDark: colorScheme == .dark, fontSize: 12)
  }
}

// MARK: - EaselTerminalContainerView

/// Container view that manages the terminal lifecycle.
class EaselTerminalContainerView: NSView, ManagedLocalProcessTerminalViewDelegate {
  var terminalView: SafeLocalProcessTerminalView?
  var localhostDetector: TerminalOutputLocalhostDetector?
  private var isConfigured = false
  private var hasDeliveredInitialPrompt = false
  private var lastAppliedFontSize: CGFloat?
  private var lastAppliedIsDark: Bool?
  private var localEventMonitor: Any?
  var onUserInteraction: (() -> Void)?

  // MARK: - Lifecycle

  deinit {
    if let localEventMonitor {
      NSEvent.removeMonitor(localEventMonitor)
    }
    terminateProcess()
  }

  /// Explicitly terminates the terminal process and its children.
  func terminateProcess() {
    terminalView?.stopReceivingData()
    terminalView?.terminateProcessTree()
  }

  // MARK: - Configuration

  func configure(projectPath: String, isDark: Bool = true) {
    guard !isConfigured else { return }
    isConfigured = true

    let initialFrame = bounds.isEmpty ? CGRect(x: 0, y: 0, width: 800, height: 600) : bounds
    let terminal = SafeLocalProcessTerminalView(frame: initialFrame)
    terminal.translatesAutoresizingMaskIntoConstraints = false
    terminal.processDelegate = self

    configureTerminalAppearance(terminal, isDark: isDark)

    addSubview(terminal)
    NSLayoutConstraint.activate([
      terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
      terminal.trailingAnchor.constraint(equalTo: trailingAnchor),
      terminal.topAnchor.constraint(equalTo: topAnchor),
      terminal.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    if let detector = localhostDetector {
      logger.info("Localhost detector wired to terminal output")
      terminal.onDataReceived = { [weak detector] slice in
        guard let text = String(bytes: slice, encoding: .utf8) else {
          logger.debug("dataReceived: \(slice.count) bytes, UTF-8 conversion failed")
          return
        }
        DispatchQueue.main.async {
          detector?.processTerminalOutput(text)
        }
      }
    } else {
      logger.warning("No localhost detector set — URL detection disabled")
    }

    self.terminalView = terminal
    installInteractionMonitorIfNeeded()

    startShellProcess(terminal: terminal, projectPath: projectPath)
  }

  /// Resets the prompt delivery flag so a new prompt can be sent.
  func resetPromptDeliveryFlag() {
    hasDeliveredInitialPrompt = false
  }

  /// Sends a prompt to the terminal (only once per reset cycle).
  func sendPromptIfNeeded(_ prompt: String) {
    guard let terminal = terminalView else { return }
    guard !hasDeliveredInitialPrompt else { return }
    hasDeliveredInitialPrompt = true

    terminal.send(txt: prompt)
    Task { @MainActor [weak terminal] in
      try? await Task.sleep(for: .milliseconds(100))
      terminal?.send([13])  // Enter
    }
  }

  /// Types text into the terminal WITHOUT pressing Enter.
  func typeText(_ text: String) {
    guard let terminal = terminalView else { return }
    terminal.send(txt: text)
  }

  func syncAppearance(isDark: Bool, fontSize: CGFloat) {
    updateColors(isDark: isDark)
    updateFont(size: fontSize)
  }

  func updateFont(size: CGFloat) {
    guard let terminal = terminalView else { return }
    let resolvedSize = max(size, 8)
    guard lastAppliedFontSize != resolvedSize else { return }

    let font = NSFont(name: "SF Mono", size: resolvedSize)
      ?? NSFont(name: "Menlo", size: resolvedSize)
      ?? NSFont.monospacedSystemFont(ofSize: resolvedSize, weight: .regular)
    terminal.font = font
    lastAppliedFontSize = resolvedSize
  }

  func updateColors(isDark: Bool) {
    guard let terminal = terminalView else { return }
    guard lastAppliedIsDark != isDark else { return }

    if isDark {
      terminal.nativeBackgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
      terminal.nativeForegroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1.0)
    } else {
      terminal.nativeBackgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
      terminal.nativeForegroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    }

    lastAppliedIsDark = isDark
    terminal.needsDisplay = true
  }

  // MARK: - Private

  private func configureTerminalAppearance(_ terminal: TerminalView, isDark: Bool) {
    let fontSize: CGFloat = 12
    lastAppliedFontSize = fontSize
    let font = NSFont(name: "SF Mono", size: fontSize)
      ?? NSFont(name: "Menlo", size: fontSize)
      ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    terminal.font = font

    if isDark {
      terminal.nativeBackgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
      terminal.nativeForegroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1.0)
    } else {
      terminal.nativeBackgroundColor = NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
      terminal.nativeForegroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
    }

    lastAppliedIsDark = isDark
  }

  private func startShellProcess(
    terminal: ManagedLocalProcessTerminalView,
    projectPath: String
  ) {
    var environment = ProcessInfo.processInfo.environment
    environment["TERM"] = "xterm-256color"
    environment["COLORTERM"] = "truecolor"
    environment["LANG"] = "en_US.UTF-8"

    let paths = [
      "/usr/local/bin",
      "/opt/homebrew/bin",
      "/usr/bin",
      "\(NSHomeDirectory())/.local/bin",
    ]
    let pathString = paths.joined(separator: ":")
    if let existingPath = environment["PATH"] {
      environment["PATH"] = "\(pathString):\(existingPath)"
    } else {
      environment["PATH"] = pathString
    }

    let workingDirectory = projectPath.isEmpty ? NSHomeDirectory() : projectPath
    let escapedPath = workingDirectory.replacingOccurrences(of: "'", with: "'\\''")
    let shellCommand = "cd '\(escapedPath)' && exec /bin/zsh"

    terminal.startProcess(
      executable: "/bin/bash",
      args: ["-c", shellCommand],
      environment: environment.map { "\($0.key)=\($0.value)" }
    )
  }

  private func installInteractionMonitorIfNeeded() {
    guard localEventMonitor == nil else { return }
    localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseUp]) {
      [weak self] event in
      guard let self, let terminal = self.terminalView else { return event }

      switch event.type {
      case .keyDown:
        guard let window = terminal.window,
          event.window === window,
          self.isTerminalResponderActive(window: window, terminal: terminal)
        else { break }
        self.onUserInteraction?()

      case .leftMouseUp:
        guard let window = terminal.window, event.window === window else { return event }
        let locationInTerminal = terminal.convert(event.locationInWindow, from: nil)
        if terminal.bounds.contains(locationInTerminal) {
          DispatchQueue.main.async { [weak self] in
            self?.onUserInteraction?()
          }
        }

      default:
        break
      }

      return event
    }
  }

  private func isTerminalResponderActive(window: NSWindow, terminal: NSView) -> Bool {
    guard let responder = window.firstResponder else { return false }
    if responder === terminal { return true }
    if let responderView = responder as? NSView {
      return responderView.isDescendant(of: terminal)
    }
    return false
  }

  // MARK: - ManagedLocalProcessTerminalViewDelegate

  func sizeChanged(source: ManagedLocalProcessTerminalView, newCols: Int, newRows: Int) {}

  func setTerminalTitle(source: ManagedLocalProcessTerminalView, title: String) {}

  func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

  func processTerminated(source: TerminalView, exitCode: Int32?) {}
}
