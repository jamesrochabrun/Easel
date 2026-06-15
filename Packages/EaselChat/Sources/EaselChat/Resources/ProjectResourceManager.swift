//
//  ProjectResourceManager.swift
//  EaselChat
//

import Foundation
import UniformTypeIdentifiers

public protocol ProjectResourceManaging: Sendable {
  func loadResources(forProjectAt projectPath: String) async throws -> [ProjectResource]
  func loadProjectStructure(forProjectAt projectPath: String) async throws -> [ProjectStructureSection]
  func loadPreview(for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview
  func saveText(_ text: String, for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview
  func importResources(from sourceURLs: [URL], intoProjectAt projectPath: String) async throws -> [ProjectResource]
  func importTextResource(named fileName: String, contents: String, intoProjectAt projectPath: String) async throws -> [ProjectResource]
  func importReferenceCodebase(from sourceURL: URL, intoProjectAt projectPath: String) async throws -> [ProjectResource]
  func deleteItem(_ item: ProjectResourcePanelItem) async throws
}

public enum ProjectResourceError: LocalizedError, Equatable, Sendable {
  case missingProjectDirectory(String)
  case missingFile
  case noImportableFiles
  case unsupportedTextEditing
  case protectedFile(String)
  case fileOutsideProject

  public var errorDescription: String? {
    switch self {
    case .missingProjectDirectory:
      return "The selected project folder could not be found."
    case .missingFile:
      return "The selected file could not be found."
    case .noImportableFiles:
      return "No importable files were selected."
    case .unsupportedTextEditing:
      return "This file type cannot be edited inline."
    case let .protectedFile(name):
      return "\(name) is required by the project and can't be deleted."
    case .fileOutsideProject:
      return "That file is outside the project folder and can't be deleted."
    }
  }
}

public actor LocalProjectResourceManager: ProjectResourceManaging {
  private static let skippedProjectDirectoryNames: Set<String> = [
    ".git", ".svn", ".build", "DerivedData", "node_modules",
    ".next", ".nuxt", "dist", "build", "coverage", ".cache",
    ".easel", ProjectResource.resourcesDirectoryName
  ]

  private static let textPreviewExtensions: Set<String> = [
    "c", "cc", "cpp", "cs", "css", "csv", "go", "h", "hpp",
    "htm", "html", "java", "js", "json", "jsx", "kt", "less",
    "log", "m", "md", "markdown", "mm", "php", "plist", "py",
    "rb", "rs", "sass", "scss", "sh", "swift", "toml", "ts",
    "tsx", "tsv", "txt", "xml", "yaml", "yml"
  ]

  private static let maxTextPreviewByteCount: Int64 = 500_000

  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  public func loadResources(forProjectAt projectPath: String) async throws -> [ProjectResource] {
    let projectURL = try validatedProjectURL(for: projectPath)
    let resourcesURL = projectURL.appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)

    guard fileManager.fileExists(atPath: resourcesURL.path) else {
      return []
    }

    let resourceURLs = files(in: resourcesURL)

    return resourceURLs.compactMap { url in
      resource(from: url, projectURL: projectURL)
    }
    .sorted { lhs, rhs in
      switch (lhs.modifiedAt, rhs.modifiedAt) {
      case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
        return lhsDate > rhsDate
      case (_?, nil):
        return true
      case (nil, _?):
        return false
      default:
        return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
      }
    }
  }

  public func loadProjectStructure(forProjectAt projectPath: String) async throws -> [ProjectStructureSection] {
    let projectURL = try validatedProjectURL(for: projectPath)
    let projectFiles = files(
      in: projectURL,
      skippingDirectoryNames: Self.skippedProjectDirectoryNames
    )

    let items = projectFiles.compactMap { url in
      projectStructureItem(from: url, projectURL: projectURL)
    }
    let groupedItems = Dictionary(grouping: items, by: \.role)

    return ProjectStructureRole.allCases.compactMap { role in
      guard let items = groupedItems[role], !items.isEmpty else {
        return nil
      }

      return ProjectStructureSection(
        role: role,
        items: items.sorted { lhs, rhs in
          lhs.relativePath.localizedCaseInsensitiveCompare(rhs.relativePath) == .orderedAscending
        }
      )
    }
  }

  public func loadPreview(for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview {
    guard fileManager.fileExists(atPath: item.fileURL.path) else {
      return ProjectResourcePreview(
        itemID: item.id,
        content: .unavailable("The selected file could not be found.")
      )
    }

    guard isTextPreviewCandidate(item.fileURL) else {
      return ProjectResourcePreview(itemID: item.id, content: .visual)
    }

    if item.byteCount > Self.maxTextPreviewByteCount {
      return ProjectResourcePreview(
        itemID: item.id,
        content: .unavailable("This text file is too large to preview inline.")
      )
    }

    let data = try Data(contentsOf: item.fileURL)
    if let text = String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .utf16)
      ?? String(data: data, encoding: .ascii) {
      return ProjectResourcePreview(itemID: item.id, content: .text(text))
    }

    return ProjectResourcePreview(
      itemID: item.id,
      content: .unavailable("This file is not stored as readable text.")
    )
  }

  public func saveText(_ text: String, for item: ProjectResourcePanelItem) async throws -> ProjectResourcePreview {
    guard fileManager.fileExists(atPath: item.fileURL.path) else {
      throw ProjectResourceError.missingFile
    }

    guard isTextPreviewCandidate(item.fileURL) else {
      throw ProjectResourceError.unsupportedTextEditing
    }

    let data = Data(text.utf8)
    try data.write(to: item.fileURL, options: .atomic)
    try touchProjectMetadata(in: URL(fileURLWithPath: item.projectPath))

    return ProjectResourcePreview(itemID: item.id, content: .text(text))
  }

  public func importResources(from sourceURLs: [URL], intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    let projectURL = try validatedProjectURL(for: projectPath)
    let resourcesURL = projectURL.appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
    try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

    var importedAnyFile = false

    for sourceURL in sourceURLs {
      let isAccessing = sourceURL.startAccessingSecurityScopedResource()
      defer {
        if isAccessing {
          sourceURL.stopAccessingSecurityScopedResource()
        }
      }

      guard isImportableFile(at: sourceURL) else {
        continue
      }

      let destinationURL = uniqueDestinationURL(
        for: sanitizedFileName(sourceURL.lastPathComponent),
        in: resourcesURL
      )
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
      importedAnyFile = true
    }

    guard importedAnyFile else {
      throw ProjectResourceError.noImportableFiles
    }

    try touchProjectMetadata(in: projectURL)
    return try await loadResources(forProjectAt: projectPath)
  }

  public func importTextResource(
    named fileName: String,
    contents: String,
    intoProjectAt projectPath: String
  ) async throws -> [ProjectResource] {
    let projectURL = try validatedProjectURL(for: projectPath)
    let trimmedContents = contents.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedContents.isEmpty else {
      throw ProjectResourceError.noImportableFiles
    }

    let resourcesURL = projectURL.appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
    try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

    let destinationURL = uniqueDestinationURL(
      for: sanitizedFileName(fileName),
      in: resourcesURL
    )
    try write(contents, to: destinationURL)
    try touchProjectMetadata(in: projectURL)
    return try await loadResources(forProjectAt: projectPath)
  }

  public func importReferenceCodebase(from sourceURL: URL, intoProjectAt projectPath: String) async throws -> [ProjectResource] {
    let projectURL = try validatedProjectURL(for: projectPath)

    let isAccessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if isAccessing {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    let sourceDirectoryURL = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: sourceDirectoryURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw ProjectResourceError.noImportableFiles
    }

    let referencesURL = projectURL
      .appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
      .appendingPathComponent("codebase-references", isDirectory: true)
    try fileManager.createDirectory(at: referencesURL, withIntermediateDirectories: true)

    let referenceURL = uniqueDestinationURL(
      for: referenceCodebaseFileName(for: sourceDirectoryURL),
      in: referencesURL
    )
    try writeReferenceCodebaseNote(
      sourceURL: sourceDirectoryURL,
      to: referenceURL
    )
    try touchProjectMetadata(in: projectURL)
    return try await loadResources(forProjectAt: projectPath)
  }

  public func deleteItem(_ item: ProjectResourcePanelItem) async throws {
    guard item.isDeletable else {
      throw ProjectResourceError.protectedFile(item.fileName)
    }

    let projectURL = try validatedProjectURL(for: item.projectPath)
    let fileURL = item.fileURL.standardizedFileURL.resolvingSymlinksInPath()

    // Defense in depth: only ever delete files that live inside the project.
    guard fileURL.path.hasPrefix(projectURL.path + "/") else {
      throw ProjectResourceError.fileOutsideProject
    }

    guard fileManager.fileExists(atPath: fileURL.path) else {
      throw ProjectResourceError.missingFile
    }

    try fileManager.removeItem(at: fileURL)
    try touchProjectMetadata(in: projectURL)
  }

  private func validatedProjectURL(for projectPath: String) throws -> URL {
    let projectURL = URL(fileURLWithPath: projectPath)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false

    guard fileManager.fileExists(atPath: projectURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw ProjectResourceError.missingProjectDirectory(projectPath)
    }

    return projectURL
  }

  private func isImportableFile(at url: URL) -> Bool {
    guard fileManager.fileExists(atPath: url.path) else {
      return false
    }

    let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
    return values?.isDirectory != true
  }

  private func writeReferenceCodebaseNote(
    sourceURL: URL,
    to destinationURL: URL
  ) throws {
    let contents = """
    # Reference codebase: \(sourceURL.lastPathComponent)

    Selected repository:

    `\(sourceURL.path)`

    Use this path only as read-only reference context for the current Easel session.

    Strict rules:

    - Do not modify files in this repository.
    - Do not create, delete, move, rename, format, or overwrite files in this repository.
    - Do not run commands that write inside this repository, including package installs, builds, generators, formatters, or git commands that change state.
    - Make all implementation changes inside the Easel project directory, not in the referenced repository.
    """
    try write(contents, to: destinationURL)
  }

  private func referenceCodebaseFileName(for sourceURL: URL) -> String {
    "\(sanitizedFileName(sourceURL.lastPathComponent)).md"
  }

  private func files(
    in directoryURL: URL,
    skippingDirectoryNames skippedDirectoryNames: Set<String> = []
  ) -> [URL] {
    guard let enumerator = fileManager.enumerator(
      at: directoryURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var urls: [URL] = []
    while let url = enumerator.nextObject() as? URL {
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
      if values?.isDirectory == true {
        if skippedDirectoryNames.contains(url.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }

      urls.append(url)
    }

    return urls
  }

  private func resource(from url: URL, projectURL: URL) -> ProjectResource? {
    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
    guard values?.isDirectory != true else {
      return nil
    }

    let fileName = url.lastPathComponent
    return ProjectResource(
      projectPath: projectURL.path,
      fileName: fileName,
      relativePath: relativePath(for: url, relativeTo: projectURL),
      fileURL: url,
      kind: kind(for: url),
      byteCount: Int64(values?.fileSize ?? 0),
      modifiedAt: values?.contentModificationDate
    )
  }

  private func projectStructureItem(from url: URL, projectURL: URL) -> ProjectStructureItem? {
    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey])
    guard values?.isDirectory != true else {
      return nil
    }

    let fileName = url.lastPathComponent
    let kind = kind(for: url)
    return ProjectStructureItem(
      projectPath: projectURL.path,
      fileName: fileName,
      relativePath: relativePath(for: url, relativeTo: projectURL),
      fileURL: url,
      kind: kind,
      role: role(for: url, kind: kind),
      byteCount: Int64(values?.fileSize ?? 0),
      modifiedAt: values?.contentModificationDate
    )
  }

  private func kind(for url: URL) -> ProjectResource.Kind {
    let pathExtension = url.pathExtension.lowercased()
    if Self.textPreviewExtensions.contains(pathExtension) {
      return .document
    }

    guard !pathExtension.isEmpty, let type = UTType(filenameExtension: pathExtension) else {
      return .other
    }

    if type.conforms(to: .image) {
      return .image
    } else if type.conforms(to: .movie) {
      return .video
    } else if type.conforms(to: .audio) {
      return .audio
    } else if type.conforms(to: .pdf) {
      return .pdf
    } else if type.conforms(to: .archive) {
      return .archive
    } else if type.conforms(to: .text) || type.conforms(to: .plainText) || type.conforms(to: .rtf) {
      return .document
    } else {
      return .other
    }
  }

  private func role(for url: URL, kind: ProjectResource.Kind) -> ProjectStructureRole {
    switch url.pathExtension.lowercased() {
    case "html", "htm":
      return .pages
    case "js", "jsx", "mjs", "cjs", "ts", "tsx":
      return .scripts
    case "css", "scss", "sass", "less":
      return .styles
    case "json", "plist", "yaml", "yml", "toml", "xml", "csv", "tsv":
      return .data
    default:
      switch kind {
      case .image, .video, .audio:
        return .assets
      case .pdf, .document:
        return .documents
      case .archive, .other:
        return .other
      }
    }
  }

  private func isTextPreviewCandidate(_ url: URL) -> Bool {
    let pathExtension = url.pathExtension.lowercased()
    if Self.textPreviewExtensions.contains(pathExtension) {
      return true
    }

    guard let type = UTType(filenameExtension: pathExtension) else {
      return false
    }

    return type.conforms(to: .text)
      || type.conforms(to: .plainText)
      || type.conforms(to: .rtf)
  }

  private func relativePath(for fileURL: URL, relativeTo rootURL: URL) -> String {
    let resolvedFilePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    let resolvedRootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
    let rootPrefix = resolvedRootPath + "/"

    guard resolvedFilePath.hasPrefix(rootPrefix) else {
      return fileURL.lastPathComponent
    }

    return String(resolvedFilePath.dropFirst(rootPrefix.count))
  }

  private func sanitizedFileName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Resource" : trimmed
  }

  private func write(_ contents: String, to url: URL) throws {
    try Data(contents.utf8).write(to: url, options: .atomic)
  }

  private func uniqueDestinationURL(for fileName: String, in directoryURL: URL) -> URL {
    var candidate = directoryURL.appendingPathComponent(fileName)
    guard fileManager.fileExists(atPath: candidate.path) else {
      return candidate
    }

    let fileURL = URL(fileURLWithPath: fileName)
    let pathExtension = fileURL.pathExtension
    let baseName: String
    if pathExtension.isEmpty {
      baseName = fileName
    } else {
      baseName = String(fileName.dropLast(pathExtension.count + 1))
    }

    var suffix = 2
    repeat {
      let nextFileName = pathExtension.isEmpty
        ? "\(baseName) \(suffix)"
        : "\(baseName) \(suffix).\(pathExtension)"
      candidate = directoryURL.appendingPathComponent(nextFileName)
      suffix += 1
    } while fileManager.fileExists(atPath: candidate.path)

    return candidate
  }

  private func touchProjectMetadata(in projectURL: URL) throws {
    let metadataURL = projectURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("project.json")

    guard fileManager.fileExists(atPath: metadataURL.path) else {
      return
    }

    let data = try Data(contentsOf: metadataURL)
    let existingProject = try decoder.decode(EaselDesignProject.self, from: data)
    let updatedProject = EaselDesignProject(
      id: existingProject.id,
      name: existingProject.name,
      kind: existingProject.kind,
      designSystem: existingProject.designSystem,
      fidelity: existingProject.fidelity,
      workingDirectory: existingProject.workingDirectory,
      createdAt: existingProject.createdAt,
      updatedAt: Date()
    )
    let updatedData = try encoder.encode(updatedProject)
    try updatedData.write(to: metadataURL, options: .atomic)
  }
}
