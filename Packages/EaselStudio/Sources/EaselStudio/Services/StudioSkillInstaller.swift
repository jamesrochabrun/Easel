import Foundation

/// Installs the bundled `easel-studio` skill for Claude and Codex: an explicit
/// `/easel-studio` trigger, plus a description the model can match on its own.
/// The system-prompt guidance (`StudioAgentGuidance`) does the everyday
/// nudging; the skill is the user's explicit handle and the fuller playbook.
public enum StudioSkillInstaller {
  public static let skillName = "easel-studio"

  enum InstallError: LocalizedError {
    case missingBundledSkill
    case invalidBundledSkillEncoding
    case missingBundledOpenAIMetadata
    case invalidBundledOpenAIMetadataEncoding

    var errorDescription: String? {
      switch self {
      case .missingBundledSkill: return "Missing bundled Easel Studio skill."
      case .invalidBundledSkillEncoding: return "Bundled Easel Studio skill is not valid UTF-8."
      case .missingBundledOpenAIMetadata: return "Missing bundled Easel Studio OpenAI metadata."
      case .invalidBundledOpenAIMetadataEncoding: return "Bundled Easel Studio OpenAI metadata is not valid UTF-8."
      }
    }
  }

  public static func installBundledSkillForAllProvidersBestEffort(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    bundle: Bundle? = nil,
    fileManager: FileManager = .default
  ) {
    do {
      try installBundledSkillForAllProviders(homeDirectory: homeDirectory, bundle: bundle, fileManager: fileManager)
    } catch {
      StudioLog.logger.error("Failed to install Easel Studio skill: \(error.localizedDescription)")
    }
  }

  public static func installBundledSkillForAllProviders(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    bundle: Bundle? = nil,
    fileManager: FileManager = .default
  ) throws {
    let bundle = bundle ?? Bundle.module
    guard let skillURL = bundle.url(forResource: "SKILL", withExtension: "md", subdirectory: "EaselStudioSkill") else {
      throw InstallError.missingBundledSkill
    }
    guard let skillMarkdown = String(data: try Data(contentsOf: skillURL), encoding: .utf8) else {
      throw InstallError.invalidBundledSkillEncoding
    }
    guard let openAIYAMLURL = bundle.url(forResource: "openai", withExtension: "yaml", subdirectory: "EaselStudioSkill/agents") else {
      throw InstallError.missingBundledOpenAIMetadata
    }
    guard let openAIYAML = String(data: try Data(contentsOf: openAIYAMLURL), encoding: .utf8) else {
      throw InstallError.invalidBundledOpenAIMetadataEncoding
    }
    try installForAllProviders(
      skillName: skillName,
      homeDirectory: homeDirectory,
      fileManager: fileManager,
      skillMarkdown: skillMarkdown,
      openAIYAML: openAIYAML
    )
  }

  /// Writes the skill into every provider's user-level skills directory
  /// (`~/.claude/skills/<name>/SKILL.md`, `~/.codex/skills/<name>/SKILL.md` +
  /// `agents/openai.yaml`). Idempotent: unchanged files are left untouched.
  static func installForAllProviders(
    skillName: String,
    homeDirectory: URL,
    fileManager: FileManager = .default,
    skillMarkdown: String,
    openAIYAML: String
  ) throws {
    let claudeSkillDirectory = homeDirectory
      .appendingPathComponent(".claude", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(skillName, isDirectory: true)
    let codexSkillDirectory = homeDirectory
      .appendingPathComponent(".codex", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(skillName, isDirectory: true)

    try write(
      skillMarkdown,
      to: claudeSkillDirectory.appendingPathComponent("SKILL.md", isDirectory: false),
      fileManager: fileManager
    )
    try write(
      skillMarkdown,
      to: codexSkillDirectory.appendingPathComponent("SKILL.md", isDirectory: false),
      fileManager: fileManager
    )
    try write(
      openAIYAML,
      to: codexSkillDirectory
        .appendingPathComponent("agents", isDirectory: true)
        .appendingPathComponent("openai.yaml", isDirectory: false),
      fileManager: fileManager
    )
  }

  private static func write(
    _ content: String,
    to url: URL,
    fileManager: FileManager
  ) throws {
    let directory = url.deletingLastPathComponent()
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    let data = Data(content.utf8)
    if let existingData = try? Data(contentsOf: url), existingData == data {
      return
    }
    try data.write(to: url, options: .atomic)
  }
}
