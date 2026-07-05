//
//  TweaksDefaultsWriteCoordinator.swift
//  EaselWebInspector
//
//  Persists updated tweak default values into the previewed HTML file.
//  Live pushes into the running page are undebounced; disk writes are
//  debounced per burst of changes and verified before landing.
//

import Canvas
import EaselKit
import Foundation
import OSLog

private let tweaksLog = Logger(subsystem: "com.easel.webinspector", category: "TweaksDefaultsWriteCoordinator")

// MARK: - TweaksDefaultsWriting

/// Persists tweak value changes back into the previewed document's source.
public protocol TweaksDefaultsWriting: Sendable {
  /// Records a value change and schedules a debounced write.
  func scheduleWrite(
    propName: String,
    value: TweakPropValue,
    filePath: String,
    liveSchemaNames: [String]
  ) async

  /// Writes any pending changes immediately (popover dismissal, view teardown).
  func flush() async

  /// True while a recent write should keep the auto-reload poller from
  /// hard-reloading the preview over our own file change.
  func isInSuppressionWindow() async -> Bool
}

// MARK: - TweaksDefaultsWriteCoordinator

public actor TweaksDefaultsWriteCoordinator: TweaksDefaultsWriting {
  private struct WriteContext {
    var filePath: String
    var liveSchemaNames: [String]
  }

  private let projectPath: String
  private let fileService: any ProjectFileProviding
  private let debounceInterval: Duration
  private let suppressionInterval: TimeInterval

  private var pendingValues: [String: TweakPropValue] = [:]
  private var pendingContext: WriteContext?
  private var debounceTask: Task<Void, Never>?
  private var suppressAutoReloadUntil: Date = .distantPast

  public init(
    projectPath: String,
    fileService: any ProjectFileProviding,
    debounceInterval: Duration = .milliseconds(400),
    suppressionInterval: TimeInterval = 1.5
  ) {
    self.projectPath = projectPath
    self.fileService = fileService
    self.debounceInterval = debounceInterval
    self.suppressionInterval = suppressionInterval
  }

  /// Resolves the on-disk path of the previewed document. File URLs resolve
  /// directly; dev-server URLs map their path into the project (heuristic —
  /// a later prop-name mismatch downgrades persistence to live-only).
  public static func resolveFilePath(previewURL: URL, projectPath: String) -> String? {
    if previewURL.isFileURL {
      return previewURL.standardizedFileURL.resolvingSymlinksInPath().path
    }
    guard let scheme = previewURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
      return nil
    }
    // URL.path strips trailing slashes, so directory URLs are detected via
    // hasDirectoryPath instead.
    var relativePath = previewURL.path
    if relativePath.isEmpty || relativePath == "/" {
      relativePath = "/index.html"
    } else if previewURL.hasDirectoryPath {
      relativePath += "/index.html"
    }
    return (projectPath as NSString).appendingPathComponent(relativePath)
  }

  public func scheduleWrite(
    propName: String,
    value: TweakPropValue,
    filePath: String,
    liveSchemaNames: [String]
  ) {
    pendingValues[propName] = value
    pendingContext = WriteContext(filePath: filePath, liveSchemaNames: liveSchemaNames)

    debounceTask?.cancel()
    debounceTask = Task { [debounceInterval] in
      try? await Task.sleep(for: debounceInterval)
      guard !Task.isCancelled else { return }
      await self.flush()
    }
  }

  public func flush() async {
    debounceTask?.cancel()
    debounceTask = nil
    guard let context = pendingContext, !pendingValues.isEmpty else { return }
    let values = pendingValues
    pendingValues = [:]
    await write(values: values, context: context)
  }

  public func isInSuppressionWindow() -> Bool {
    Date() < suppressAutoReloadUntil
  }

  // MARK: - Write path

  private func write(values: [String: TweakPropValue], context: WriteContext) async {
    guard let source = try? await fileService.readFile(at: context.filePath, projectPath: projectPath) else {
      tweaksLog.debug("Tweaks persist skipped: cannot read \(context.filePath)")
      return
    }

    // The file must declare exactly the props the live page reported;
    // otherwise the preview URL maps to the wrong document (or the agent
    // rewrote it) and persisting would corrupt an unrelated declaration.
    guard let diskNames = try? TweakPropsSourceEditor.parsePropNames(fromSource: source),
          Set(diskNames) == Set(context.liveSchemaNames) else {
      tweaksLog.debug("Tweaks persist skipped: prop names on disk don't match live schema")
      return
    }

    var edited = source
    var appliedAny = false
    for (name, value) in values {
      do {
        edited = try TweakPropsSourceEditor.applyingValueEdit(
          propName: name,
          newValue: value,
          toSource: edited
        )
        appliedAny = true
      } catch {
        tweaksLog.debug("Tweaks persist skipped for \(name): \(error)")
      }
    }
    guard appliedAny, edited != source else { return }

    do {
      // Extend the window before the write lands so the poller can never
      // observe the change outside it.
      suppressAutoReloadUntil = Date().addingTimeInterval(suppressionInterval)
      try await fileService.writeFile(at: context.filePath, content: edited, projectPath: projectPath)
      suppressAutoReloadUntil = Date().addingTimeInterval(suppressionInterval)
      tweaksLog.debug("Tweaks persisted \(values.count) value(s) to \(context.filePath)")
    } catch {
      tweaksLog.error("Tweaks persist failed for \(context.filePath): \(error.localizedDescription)")
    }
  }
}
