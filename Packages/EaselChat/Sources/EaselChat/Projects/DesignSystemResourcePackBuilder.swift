//
//  DesignSystemResourcePackBuilder.swift
//  EaselChat
//

import EaselDesignSystems
import Foundation

protocol DesignSystemResourcePacking: Sendable {
  func writeResourcePack(
    for designSystem: EaselDesignSystemChoice,
    intoProjectAt projectURL: URL
  ) throws
}

struct DesignSystemResourcePackManifest: Codable, Equatable, Sendable {
  let designSystemID: String
  let designSystemName: String
  let embeddedAt: Date
  let sourceWorkingDirectory: String
  let entryPoints: [String]
  let componentCount: Int
  let exampleCount: Int
  let assetCount: Int
  let codeExampleCount: Int
  let sourceCatalogGeneratedAt: Date?
}

struct LocalDesignSystemResourcePackBuilder: DesignSystemResourcePacking {
  private static let packDirectoryPath = "resources/design-system"
  private static let entryPointPaths = [
    "resources/design-system/README.md",
    "resources/design-system/DESIGN.md",
    "resources/design-system/components.md",
    "resources/design-system/examples.md",
    "resources/design-system/assets.md",
    "resources/design-system/catalog.json",
    "resources/design-system/manifest.json",
  ]
  private static let skippedDirectoryNames: Set<String> = [
    ".git", ".svn", "node_modules", ".build", "build", "dist", "DerivedData", ".cache",
  ]

  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  func writeResourcePack(
    for designSystem: EaselDesignSystemChoice,
    intoProjectAt projectURL: URL
  ) throws {
    guard designSystem.kind == .custom else { return }

    let sourceURL = try validatedDesignSystemURL(for: designSystem)
    let packURL = projectURL.appendingPathComponent(Self.packDirectoryPath, isDirectory: true)
    try fileManager.createDirectory(at: packURL, withIntermediateDirectories: true)

    let sourceCatalog = try loadCatalog(from: sourceURL)
    let catalog = sourceCatalog ?? fallbackCatalog(for: designSystem)

    try writeDesignMarkdown(for: designSystem, sourceURL: sourceURL, catalog: sourceCatalog, to: packURL)

    var pathMapper = DesignSystemResourcePathMapper(
      sourceRootURL: sourceURL,
      projectRootURL: projectURL,
      packURL: packURL,
      fileManager: fileManager
    )
    let rebasedCatalog = try pathMapper.rebasedCatalog(catalog)
    let importedAssetReferences = try copyImportedAssets(
      from: sourceURL,
      using: &pathMapper
    )
    let assetReferences = (pathMapper.assetReferences + importedAssetReferences)
      .deduplicatedByPath()
      .sortedByPath()
    let codeExamplePaths = try copyCodeExamples(from: sourceURL, to: packURL)

    try write(rebasedCatalog, to: packURL.appendingPathComponent("catalog.json"))
    try write(componentsIndex(for: rebasedCatalog), to: packURL.appendingPathComponent("components.md"))
    try write(examplesIndex(for: rebasedCatalog), to: packURL.appendingPathComponent("examples.md"))
    try write(assetsIndex(for: assetReferences), to: packURL.appendingPathComponent("assets.md"))
    try write(readme(for: designSystem), to: packURL.appendingPathComponent("README.md"))

    let manifest = DesignSystemResourcePackManifest(
      designSystemID: designSystem.referenceID,
      designSystemName: designSystem.displayName,
      embeddedAt: Date.now,
      sourceWorkingDirectory: sourceURL.path,
      entryPoints: Self.entryPointPaths,
      componentCount: rebasedCatalog.componentFamilies?.count ?? 0,
      exampleCount: rebasedCatalog.examples?.count ?? 0,
      assetCount: assetReferences.count,
      codeExampleCount: codeExamplePaths.count,
      sourceCatalogGeneratedAt: sourceCatalog?.generatedAt
    )
    try write(manifest, to: packURL.appendingPathComponent("manifest.json"))
  }

  private func validatedDesignSystemURL(for designSystem: EaselDesignSystemChoice) throws -> URL {
    guard let workingDirectory = designSystem.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
          !workingDirectory.isEmpty else {
      throw EaselProjectManagerError.missingDesignSystemDirectory(designSystem.displayName)
    }

    let url = URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw EaselProjectManagerError.missingDesignSystemDirectory(workingDirectory)
    }

    return url
  }

  private func loadCatalog(from sourceURL: URL) throws -> EaselDesignSystemCatalog? {
    let catalogURL = sourceURL
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("catalog.json")
    guard fileManager.fileExists(atPath: catalogURL.path) else { return nil }

    let data = try Data(contentsOf: catalogURL)
    return try decoder.decode(EaselDesignSystemCatalog.self, from: data)
  }

  private func fallbackCatalog(for designSystem: EaselDesignSystemChoice) -> EaselDesignSystemCatalog {
    let summary = designSystem.detail.trimmingCharacters(in: .whitespacesAndNewlines)
    return EaselDesignSystemCatalog(
      name: designSystem.displayName,
      summary: summary.isEmpty ? "\(designSystem.displayName) design system." : summary,
      generatedAt: nil,
      componentGroups: [],
      title: designSystem.displayName,
      isReference: true,
      disclaimer: "Design-system catalog was not available when this project was created."
    )
  }

  private func writeDesignMarkdown(
    for designSystem: EaselDesignSystemChoice,
    sourceURL: URL,
    catalog: EaselDesignSystemCatalog?,
    to packURL: URL
  ) throws {
    let sourceMarkdownURL = sourceURL.appendingPathComponent("DESIGN.md")
    let destinationURL = packURL.appendingPathComponent("DESIGN.md")

    if let canonical = try? Data(contentsOf: sourceMarkdownURL), !canonical.isEmpty {
      try canonical.write(to: destinationURL, options: .atomic)
      return
    }

    let markdown = DesignSystemBriefBuilder.markdown(
      displayName: designSystem.displayName,
      detail: designSystem.detail,
      notes: designSystem.notes,
      catalog: catalog
    )
    try write(markdown, to: destinationURL)
  }

  private func copyImportedAssets(
    from sourceURL: URL,
    using pathMapper: inout DesignSystemResourcePathMapper
  ) throws -> [DesignSystemResourceAssetReference] {
    let assetsURL = sourceURL
      .appendingPathComponent("resources", isDirectory: true)
      .appendingPathComponent("assets", isDirectory: true)
    guard fileManager.fileExists(atPath: assetsURL.path) else { return [] }

    return try files(in: assetsURL, skippingDirectoryNames: Self.skippedDirectoryNames).compactMap { fileURL in
      let sourceRelativePath = relativePath(for: fileURL, relativeTo: sourceURL)
      guard let projectRelativePath = try pathMapper.copiedAssetProjectPath(for: sourceRelativePath) else {
        return nil
      }
      return DesignSystemResourceAssetReference(
        name: fileURL.deletingPathExtension().lastPathComponent,
        kind: "asset",
        projectRelativePath: projectRelativePath
      )
    }
  }

  private func copyCodeExamples(from sourceURL: URL, to packURL: URL) throws -> [String] {
    let sourceCodeURL = sourceURL
      .appendingPathComponent("resources", isDirectory: true)
      .appendingPathComponent("code", isDirectory: true)
    guard fileManager.fileExists(atPath: sourceCodeURL.path) else { return [] }

    let destinationCodeURL = packURL.appendingPathComponent("code", isDirectory: true)
    let sourceFiles = files(in: sourceCodeURL, skippingDirectoryNames: Self.skippedDirectoryNames)
    var copiedPaths: [String] = []

    for sourceFileURL in sourceFiles {
      let relativeCodePath = relativePath(for: sourceFileURL, relativeTo: sourceCodeURL)
      let destinationURL = destinationCodeURL.appendingPathComponent(relativeCodePath)
      try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }
      try fileManager.copyItem(at: sourceFileURL, to: destinationURL)
      copiedPaths.append("resources/design-system/code/\(relativeCodePath)")
    }

    return copiedPaths.sorted()
  }

  private func componentsIndex(for catalog: EaselDesignSystemCatalog) -> String {
    var lines = [
      "# Design System Components",
      "",
      "Use this file as a searchable index. Read `catalog.json` only when you need exact preview geometry or additional metadata for a specific component.",
      "",
    ]

    guard let allFamilies = catalog.componentFamilies, !allFamilies.isEmpty else {
      lines.append("No component families were available when this project was created.")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    let families = allFamilies.filter(\.isHighSignalIndexEntry)
    let omittedCount = allFamilies.count - families.count
    if families.isEmpty {
      lines.append("Only low-signal one-off component candidates were available; they were omitted from this component index.")
      lines.append("")
      lines.append("Search `catalog.json` by exact title only when a specific icon or object-like candidate is required.")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    if omittedCount > 0 {
      let pluralSuffix = omittedCount == 1 ? "" : "s"
      lines.append(
        "> Omitted \(omittedCount) low-signal one-off candidate\(pluralSuffix) from this index. Search `catalog.json` by exact title only when a specific icon or object-like candidate is required."
      )
      lines.append("")
    }

    for family in families {
      lines.append("## \(family.title)")
      lines.append("")
      lines.append("- Category: \(family.category)")
      if let sourcePage = family.sourcePage, !sourcePage.isEmpty {
        lines.append("- Source page: \(sourcePage)")
      }
      if !family.summary.isEmpty {
        lines.append("- Summary: \(family.summary)")
      }
      lines.append("- Variants: \(family.variantCount)")
      for property in family.variantProperties {
        lines.append("- \(property.name): \(property.values.joined(separator: ", "))")
      }
      let imagePaths = imagePaths(in: family.preview)
      if !imagePaths.isEmpty {
        lines.append("- Preview assets: \(imagePaths.map { "`\($0)`" }.joined(separator: ", "))")
      }
      lines.append("")
    }

    return lines.joined(separator: "\n")
  }

  private func examplesIndex(for catalog: EaselDesignSystemCatalog) -> String {
    var lines = [
      "# Design System Examples",
      "",
      "Use these examples as product and layout references before inventing new screens.",
      "",
    ]

    guard let allExamples = catalog.examples, !allExamples.isEmpty else {
      lines.append("No example screens were available when this project was created.")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    let examples = allExamples.filter(\.isHighSignalIndexEntry)
    let omittedCount = allExamples.count - examples.count
    if examples.isEmpty {
      lines.append("Only component documentation or foundation reference pages were available; they were omitted from this examples index.")
      lines.append("")
      lines.append("Search `catalog.json` by exact title only when a specific source frame is required.")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    if omittedCount > 0 {
      let pluralSuffix = omittedCount == 1 ? "" : "s"
      lines.append(
        "> Omitted \(omittedCount) component documentation or foundation reference page\(pluralSuffix) from this index."
      )
      lines.append("")
    }

    for example in examples {
      lines.append("## \(example.title)")
      lines.append("")
      if let sourcePage = example.sourcePage, !sourcePage.isEmpty {
        lines.append("- Source page: \(sourcePage)")
      }
      let imagePaths = imagePaths(in: example.preview)
      if !imagePaths.isEmpty {
        lines.append("- Preview assets: \(imagePaths.map { "`\($0)`" }.joined(separator: ", "))")
      }
      lines.append("")
    }

    return lines.joined(separator: "\n")
  }

  private func assetsIndex(for assets: [DesignSystemResourceAssetReference]) -> String {
    var lines = [
      "# Design System Assets",
      "",
      "Copy assets into project UI from these local project-relative paths. Do not reference the original design-system folder.",
      "",
    ]

    guard !assets.isEmpty else {
      lines.append("No reusable assets were available when this project was created.")
      lines.append("")
      return lines.joined(separator: "\n")
    }

    for asset in assets {
      lines.append("- \(asset.name) (\(asset.kind)): `\(asset.projectRelativePath)`")
    }
    lines.append("")
    return lines.joined(separator: "\n")
  }

  private func readme(for designSystem: EaselDesignSystemChoice) -> String {
    """
    # \(designSystem.displayName) Resource Pack

    This folder is a project-local snapshot of the selected Easel design system.

    Start with `DESIGN.md` for tokens and rules, then search these indexes when the task needs reusable components, example screens, or assets:

    - `components.md`
    - `examples.md`
    - `assets.md`
    - `catalog.json`

    Keep implementation changes in the current project. Do not reference the original design-system folder from prototype UI.
    """
  }

  private func imagePaths(in scene: EaselDesignSystemPreviewScene?) -> [String] {
    guard let scene else { return [] }
    return Array(Set(scene.layers.compactMap(\.imagePath))).sorted()
  }

  private func files(
    in directoryURL: URL,
    skippingDirectoryNames skippedDirectoryNames: Set<String>
  ) -> [URL] {
    guard let enumerator = fileManager.enumerator(
      at: directoryURL,
      includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var urls: [URL] = []
    while let url = enumerator.nextObject() as? URL {
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
      if values?.isDirectory == true {
        if skippedDirectoryNames.contains(url.lastPathComponent) {
          enumerator.skipDescendants()
        }
        continue
      }
      if values?.isRegularFile == true {
        urls.append(url)
      }
    }
    return urls.sorted { lhs, rhs in
      lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
    }
  }

  private func relativePath(for fileURL: URL, relativeTo rootURL: URL) -> String {
    let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    let rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
    let prefix = rootPath + "/"
    guard filePath.hasPrefix(prefix) else {
      return fileURL.lastPathComponent
    }
    return String(filePath.dropFirst(prefix.count))
  }

  private func write<T: Encodable>(_ value: T, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
  }

  private func write(_ value: String, to url: URL) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(value.utf8).write(to: url, options: .atomic)
  }
}

private struct DesignSystemResourceAssetReference: Equatable {
  let name: String
  let kind: String
  let projectRelativePath: String
}

private struct DesignSystemResourcePathMapper {
  private let sourceRootURL: URL
  private let projectRootURL: URL
  private let packURL: URL
  private let fileManager: FileManager
  private var pathMap: [String: String] = [:]
  private var reservedDestinationPaths: Set<String> = []

  private(set) var assetReferences: [DesignSystemResourceAssetReference] = []

  init(
    sourceRootURL: URL,
    projectRootURL: URL,
    packURL: URL,
    fileManager: FileManager
  ) {
    self.sourceRootURL = sourceRootURL
    self.projectRootURL = projectRootURL
    self.packURL = packURL
    self.fileManager = fileManager
  }

  mutating func rebasedCatalog(_ catalog: EaselDesignSystemCatalog) throws -> EaselDesignSystemCatalog {
    let assets = try catalog.assets?.compactMap { asset -> EaselDesignSystemAsset? in
      guard let projectRelativePath = try copiedAssetProjectPath(for: asset.relativePath) else {
        return nil
      }
      return EaselDesignSystemAsset(
        id: asset.id,
        name: asset.name,
        relativePath: projectRelativePath,
        kind: asset.kind
      )
    }

    let heroThumbnailPath: String?
    if let sourceHeroThumbnailPath = catalog.heroThumbnailPath {
      heroThumbnailPath = try copiedAssetProjectPath(for: sourceHeroThumbnailPath)
    } else {
      heroThumbnailPath = nil
    }

    return EaselDesignSystemCatalog(
      name: catalog.name,
      summary: catalog.summary,
      generatedAt: catalog.generatedAt,
      componentGroups: catalog.componentGroups,
      title: catalog.title,
      isReference: catalog.isReference,
      disclaimer: catalog.disclaimer,
      tokens: catalog.tokens,
      componentFamilies: try catalog.componentFamilies?.map { try rebasedComponentFamily($0) },
      examples: try catalog.examples?.map { try rebasedExample($0) },
      assets: assets,
      heroThumbnailPath: heroThumbnailPath,
      sourceDiagnostics: catalog.sourceDiagnostics
    )
  }

  mutating func copiedAssetProjectPath(for sourceRelativePath: String) throws -> String? {
    let sourceRelativePath = sourceRelativePath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let sourceFileURL = sourceFileURL(for: sourceRelativePath) else { return nil }

    if let existing = pathMap[sourceRelativePath] {
      return existing
    }

    let preferredPackPath = packAssetPath(for: sourceRelativePath)
    let preferredDestinationURL = packURL.appendingPathComponent(preferredPackPath)
    let destinationURL = uniqueDestinationURL(for: preferredDestinationURL)
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fileManager.copyItem(at: sourceFileURL, to: destinationURL)

    let projectRelativePath = relativePath(for: destinationURL, relativeTo: projectRootURL)
    pathMap[sourceRelativePath] = projectRelativePath
    assetReferences.append(DesignSystemResourceAssetReference(
      name: sourceFileURL.deletingPathExtension().lastPathComponent,
      kind: assetKind(for: sourceRelativePath),
      projectRelativePath: projectRelativePath
    ))
    return projectRelativePath
  }

  private mutating func rebasedComponentFamily(
    _ family: EaselDesignSystemComponentFamily
  ) throws -> EaselDesignSystemComponentFamily {
    EaselDesignSystemComponentFamily(
      id: family.id,
      title: family.title,
      category: family.category,
      summary: family.summary,
      sourcePage: family.sourcePage,
      variantCount: family.variantCount,
      variantProperties: family.variantProperties,
      preview: try rebasedScene(family.preview),
      confidence: family.confidence
    )
  }

  private mutating func rebasedExample(
    _ example: EaselDesignSystemExample
  ) throws -> EaselDesignSystemExample {
    EaselDesignSystemExample(
      id: example.id,
      title: example.title,
      sourcePage: example.sourcePage,
      preview: try rebasedScene(example.preview)
    )
  }

  private mutating func rebasedScene(
    _ scene: EaselDesignSystemPreviewScene?
  ) throws -> EaselDesignSystemPreviewScene? {
    guard let scene else { return nil }
    return EaselDesignSystemPreviewScene(
      width: scene.width,
      height: scene.height,
      background: scene.background,
      layers: try scene.layers.map { try rebasedLayer($0) }
    )
  }

  private mutating func rebasedLayer(
    _ layer: EaselDesignSystemPreviewLayer
  ) throws -> EaselDesignSystemPreviewLayer {
    let imagePath: String?
    if let sourceImagePath = layer.imagePath {
      imagePath = try copiedAssetProjectPath(for: sourceImagePath)
    } else {
      imagePath = nil
    }

    return EaselDesignSystemPreviewLayer(
      id: layer.id,
      kind: layer.kind,
      x: layer.x,
      y: layer.y,
      width: layer.width,
      height: layer.height,
      cornerRadius: layer.cornerRadius,
      fill: layer.fill,
      stroke: layer.stroke,
      strokeWidth: layer.strokeWidth,
      opacity: layer.opacity,
      text: layer.text,
      fontSize: layer.fontSize,
      fontWeight: layer.fontWeight,
      textColor: layer.textColor,
      align: layer.align,
      imagePath: imagePath,
      path: layer.path
    )
  }

  private func sourceFileURL(for relativePath: String) -> URL? {
    guard !relativePath.isEmpty,
          relativePath.hasPrefix("/") == false,
          relativePath.split(separator: "/").contains(where: { $0 == ".." }) == false,
          isExternalPath(relativePath) == false else {
      return nil
    }

    let url = sourceRootURL
      .appendingPathComponent(relativePath)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    guard url.path.hasPrefix(sourceRootURL.path + "/"),
          fileManager.fileExists(atPath: url.path) else {
      return nil
    }
    return url
  }

  private func isExternalPath(_ value: String) -> Bool {
    value.hasPrefix("http://") || value.hasPrefix("https://") || value.hasPrefix("data:")
  }

  private func packAssetPath(for sourceRelativePath: String) -> String {
    if sourceRelativePath.hasPrefix(".easel/assets/") {
      return "assets/extracted/\(sourceRelativePath.dropFirst(".easel/assets/".count))"
    }
    if sourceRelativePath.hasPrefix("resources/assets/") {
      return "assets/imported/\(sourceRelativePath.dropFirst("resources/assets/".count))"
    }
    return "assets/references/\(sanitizedPath(sourceRelativePath))"
  }

  private func sanitizedPath(_ path: String) -> String {
    path.split(separator: "/")
      .map { sanitizedFileName(String($0)) }
      .joined(separator: "/")
  }

  private func sanitizedFileName(_ fileName: String) -> String {
    let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "asset" }
    let invalidScalars = CharacterSet(charactersIn: "/:")
    let filtered = trimmed.unicodeScalars.map { scalar in
      invalidScalars.contains(scalar) ? "-" : String(scalar)
    }.joined()
    return filtered.isEmpty ? "asset" : filtered
  }

  private mutating func uniqueDestinationURL(for preferredURL: URL) -> URL {
    var candidate = preferredURL
    guard fileManager.fileExists(atPath: candidate.path) || reservedDestinationPaths.contains(candidate.path) else {
      reservedDestinationPaths.insert(candidate.path)
      return candidate
    }

    let directoryURL = preferredURL.deletingLastPathComponent()
    let pathExtension = preferredURL.pathExtension
    let baseName = pathExtension.isEmpty
      ? preferredURL.lastPathComponent
      : preferredURL.deletingPathExtension().lastPathComponent
    var suffix = 2

    repeat {
      let nextName = pathExtension.isEmpty
        ? "\(baseName)-\(suffix)"
        : "\(baseName)-\(suffix).\(pathExtension)"
      candidate = directoryURL.appendingPathComponent(nextName)
      suffix += 1
    } while fileManager.fileExists(atPath: candidate.path) || reservedDestinationPaths.contains(candidate.path)

    reservedDestinationPaths.insert(candidate.path)
    return candidate
  }

  private func relativePath(for fileURL: URL, relativeTo rootURL: URL) -> String {
    let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    let rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
    let prefix = rootPath + "/"
    guard filePath.hasPrefix(prefix) else {
      return fileURL.lastPathComponent
    }
    return String(filePath.dropFirst(prefix.count))
  }

  private func assetKind(for sourceRelativePath: String) -> String {
    if sourceRelativePath.hasPrefix(".easel/assets/") {
      return "extracted"
    }
    if sourceRelativePath.hasPrefix("resources/assets/") {
      return "asset"
    }
    return "reference"
  }
}

private extension Array where Element == DesignSystemResourceAssetReference {
  func deduplicatedByPath() -> [DesignSystemResourceAssetReference] {
    var seen: Set<String> = []
    var result: [DesignSystemResourceAssetReference] = []
    for asset in self where seen.insert(asset.projectRelativePath).inserted {
      result.append(asset)
    }
    return result
  }

  func sortedByPath() -> [DesignSystemResourceAssetReference] {
    sorted {
      $0.projectRelativePath.localizedCaseInsensitiveCompare($1.projectRelativePath) == .orderedAscending
    }
  }
}
