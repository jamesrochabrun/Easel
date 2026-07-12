//
//  TweaksDefaultsWriteCoordinator.swift
//  EaselWebInspector
//
//  Explicitly persists live tweak values into the previewed HTML file after
//  verifying that its declared defaults still match the loaded panel state.
//

import Canvas
import EaselKit
import Foundation
import OSLog

private let tweaksLog = Logger(subsystem: "com.easel.webinspector", category: "TweaksDefaultsWriteCoordinator")

// MARK: - TweaksDefaultsWriting

/// Persists tweak value changes back into the previewed document's source.
public protocol TweaksDefaultsWriting: Sendable {
  /// Atomically promotes the changed live values to source-declared defaults.
  func saveDefaults(props: [TweakProp], filePath: String) async throws

  /// True while a recent write should keep the auto-reload poller from
  /// hard-reloading the preview over our own file change.
  func isInSuppressionWindow() async -> Bool
}

// MARK: - TweaksDefaultsWriteCoordinator

public actor TweaksDefaultsWriteCoordinator: TweaksDefaultsWriting {
  private let projectPath: String
  private let fileService: any ProjectFileProviding
  private let suppressionInterval: TimeInterval

  private var suppressAutoReloadUntil: Date = .distantPast

  public init(
    projectPath: String,
    fileService: any ProjectFileProviding,
    suppressionInterval: TimeInterval = 1.5
  ) {
    self.projectPath = projectPath
    self.fileService = fileService
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

  public func isInSuppressionWindow() -> Bool {
    Date() < suppressAutoReloadUntil
  }

  // MARK: - Write path

  public func saveDefaults(props: [TweakProp], filePath: String) async throws {
    let changedProps = props.filter { $0.value != $0.defaultValue }
    guard !changedProps.isEmpty else { return }

    let source: String
    do {
      source = try await fileService.readFile(at: filePath, projectPath: projectPath)
    } catch {
      tweaksLog.error("Tweaks defaults read failed for \(filePath): \(error.localizedDescription)")
      throw TweaksDefaultsWriteError.cannotReadFile
    }

    guard let diskNames = try? TweakPropsSourceEditor.parsePropNames(fromSource: source),
          diskNames == props.map(\.name) else {
      throw TweaksDefaultsWriteError.sourceChanged
    }

    guard let diskProps = try? TweakPropsSourceEditor.parseProps(fromSource: source) else {
      throw TweaksDefaultsWriteError.sourceChanged
    }
    let diskPropsByName = Dictionary(uniqueKeysWithValues: diskProps.map { ($0.name, $0) })
    for prop in props {
      guard let diskProp = diskPropsByName[prop.name] else {
        throw TweaksDefaultsWriteError.unsupportedValue(prop.name)
      }
      guard diskProp == sourceBaseline(for: prop) else {
        throw TweaksDefaultsWriteError.sourceChanged
      }
    }

    var edited = source
    for prop in changedProps {
      do {
        edited = try TweakPropsSourceEditor.applyingValueEdit(
          propName: prop.name,
          newValue: prop.value,
          toSource: edited
        )
      } catch {
        throw TweaksDefaultsWriteError.unsupportedValue(prop.name)
      }
    }
    guard edited != source else { return }

    do {
      suppressAutoReloadUntil = Date().addingTimeInterval(suppressionInterval)
      try await fileService.writeFile(at: filePath, content: edited, projectPath: projectPath)
      suppressAutoReloadUntil = Date().addingTimeInterval(suppressionInterval)
      tweaksLog.debug("Tweaks saved \(changedProps.count) default value(s) to \(filePath)")
    } catch {
      suppressAutoReloadUntil = .distantPast
      tweaksLog.error("Tweaks defaults write failed for \(filePath): \(error.localizedDescription)")
      throw TweaksDefaultsWriteError.writeFailed(error.localizedDescription)
    }
  }

  private func sourceBaseline(for prop: TweakProp) -> TweakProp {
    TweakProp(
      name: prop.name,
      label: prop.label,
      type: prop.type,
      minimum: prop.minimum,
      maximum: prop.maximum,
      step: prop.step,
      options: prop.options,
      value: prop.defaultValue,
      defaultValue: prop.defaultValue
    )
  }
}
