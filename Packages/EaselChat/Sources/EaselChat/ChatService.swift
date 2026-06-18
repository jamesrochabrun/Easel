//
//  ChatService.swift
//  EaselChat
//

import ClaudeCodeCore
import ClaudeCodeSDK
import EaselDesignSystems
import EaselKit
import Foundation
import OSLog

private let chatLog = Logger(subsystem: "com.easel.chat", category: "ChatService")

private struct ResourceManifestCacheKey: Hashable {
  let sessionId: String
  let workingDirectory: String
}

@Observable @MainActor
public final class ChatService: ChatServiceProtocol, InspectorBridgeProtocol, PreviewURLProviding {

  // MARK: - Public State

  public private(set) var chatViewModel: ChatViewModel?
  public private(set) var deps: DependencyContainer?
  public private(set) var globalPreferences: GlobalPreferencesStorage?
  public private(set) var isInitialized = false
  public private(set) var initError: Error?
  public private(set) var previewURL: URL?
  public private(set) var currentSessionId: String?
  public private(set) var currentWorkingDirectory: String?
  public private(set) var currentProject: EaselDesignProject?
  public private(set) var currentWorkspaceUsageSummary: SessionUsageSummary = .zero
  public private(set) var sessionStorage: SessionStorageProtocol
  public var mcpToolsDiscoveryService: MCPToolsDiscoveryService { mcpToolsDiscovery }

  /// Called when a session changes (created or switched), so the sidebar can refresh
  public var onSessionChanged: (() -> Void)?

  private var isInitializing = false
  private let previewURLObserver = PreviewURLObserver()
  private let projectManager: any EaselProjectManaging
  private let persistentPreferencesManager: PersistentPreferencesManager
  private let mcpToolsDiscovery: MCPToolsDiscoveryService
  private let logger: ClaudeCodeLogger
  private var previewURLSource: PreviewURLSource?
  private var currentProjectLookupTask: Task<Void, Never>?
  private var currentWorkspaceUsageTask: Task<Void, Never>?
  private var lastSentResourceManifestBySession: [ResourceManifestCacheKey: [String: ProjectResourceFileSignature]] = [:]
  private var pendingResourceManifestByWorkingDirectory: [String: [String: ProjectResourceFileSignature]] = [:]

  // MARK: - Init

  public init(
    sessionStorage: SessionStorageProtocol = SimplifiedClaudeCodeSQLiteStorage(),
    projectManager: any EaselProjectManaging = LocalEaselProjectManager(),
    persistentPreferencesManager: PersistentPreferencesManager? = nil,
    mcpToolsDiscovery: MCPToolsDiscoveryService = MCPToolsDiscoveryService(),
    logger: ClaudeCodeLogger = ClaudeCodeLogger()
  ) {
    self.sessionStorage = sessionStorage
    self.projectManager = projectManager
    self.mcpToolsDiscovery = mcpToolsDiscovery
    self.logger = logger
    self.persistentPreferencesManager = persistentPreferencesManager ?? PersistentPreferencesManager(logger: logger)
  }

  // MARK: - Initialization

  public func initialize() async {
    guard !isInitialized else { return }
    if isInitializing {
      while isInitializing && !isInitialized {
        try? await Task.sleep(for: .milliseconds(50))
      }
      return
    }

    isInitializing = true
    defer { isInitializing = false }

    do {
      let globalPrefs = GlobalPreferencesStorage(
        persistentManager: persistentPreferencesManager,
        logger: logger
      )
      let container = DependencyContainer(
        globalPreferences: globalPrefs,
        customSessionStorage: sessionStorage,
        mcpToolsDiscovery: mcpToolsDiscovery,
        logger: logger
      )

      var config = ChatConfiguration.makeDefault()
      config.command = globalPrefs.claudeCommand

      let client = try ClaudeCodeClient(configuration: config)

      // Set working directory
      if let dir = config.workingDirectory {
        container.settingsStorage.setProjectPath(dir)
      }

      let vm = ChatViewModel(
        claudeClient: client,
        sessionStorage: sessionStorage,
        settingsStorage: container.settingsStorage,
        globalPreferences: globalPrefs,
        customPermissionService: container.customPermissionService,
        mcpToolsDiscovery: mcpToolsDiscovery,
        logger: logger,
        systemPromptPrefix: EaselAgentInstructions.systemPromptPrefix,
        codexDeveloperInstructionsPrefix: EaselAgentInstructions.codexDeveloperInstructionsPrefix,
        shouldManageSessions: true,
        onSessionChange: { [weak self] newSessionId in
          Task { @MainActor in
            self?.setCurrentSessionId(newSessionId)
            self?.refreshCurrentWorkspaceUsage()
            self?.onSessionChanged?()
          }
        },
        onSessionUsageChange: { [weak self] _ in
          Task { @MainActor in
            self?.refreshCurrentWorkspaceUsage()
            self?.onSessionChanged?()
          }
        }
      )
      vm.runtimeHiddenContextProvider = { [weak self] in
        self?.makeHiddenContextForCurrentState(nil)
      }
      vm.outgoingHiddenContextProvider = { [weak self] in
        self?.resourceManifestDeltaContextForOutgoingMessage()
      }

      if let dir = config.workingDirectory {
        vm.projectPath = dir
        setCurrentWorkingDirectory(dir)
      }
      setCurrentWorkingDirectory(vm.projectPath)

      self.chatViewModel = vm
      self.deps = container
      self.globalPreferences = globalPrefs
      self.isInitialized = true

      startPreviewObservation()
    } catch {
      self.initError = error
    }
  }

  public func retry() {
    previewURLObserver.stopObserving()
    initError = nil
    isInitialized = false
    clearPreviewURL()
    Task { await initialize() }
  }

  // MARK: - ChatServiceProtocol

  public func sendMessage(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    sendMessageToViewModel(text, context: context, hiddenContext: hiddenContext)
  }

  // MARK: - InspectorBridgeProtocol

  public func sendInspectorPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt)
  }

  public func sendContextPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt, hiddenContext: prompt)
  }

  public func sendCropPrompt(_ prompt: String) {
    sendMessageToViewModel(prompt)
  }

  // MARK: - Session Management

  public func switchToSession(_ session: StoredSession) async {
    previewURLObserver.stopObserving()

    // Save current session before switching
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }

    // Load fresh session data from storage, fall back to the passed object
    let sessionToLoad: StoredSession
    if let stored = try? await sessionStorage.getSession(id: session.id) {
      sessionToLoad = stored
    } else {
      sessionToLoad = session
    }

    if let workingDirectory = sessionToLoad.workingDirectory {
      setCurrentWorkingDirectory(workingDirectory)
    }

    // injectSession handles updating working directory on the existing client
    chatViewModel?.injectSession(
      sessionId: sessionToLoad.id,
      messages: sessionToLoad.messages,
      workingDirectory: sessionToLoad.workingDirectory,
      provider: sessionToLoad.provider,
      usageSummary: sessionToLoad.usageSummary
    )

    setCurrentWorkingDirectory(sessionToLoad.workingDirectory ?? chatViewModel?.projectPath)
    setCurrentSessionId(session.id)
    clearPreviewURL()

    // Immediately scan loaded messages for a dev server URL
    if let detectedURL = previewURLObserver.scanExistingMessages(sessionToLoad.messages) {
      applyDetectedPreviewURL(detectedURL)
    }

    startPreviewObservation()
  }

  public func startNewSession(workingDirectory: String?) async {
    previewURLObserver.stopObserving()

    // Save current session before starting new one
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }

    chatViewModel?.startNewSession(workingDirectory: workingDirectory)

    // Set the working directory for the new chat
    if let dir = workingDirectory, !dir.isEmpty {
      setCurrentWorkingDirectory(dir)
    } else {
      setCurrentWorkingDirectory(chatViewModel?.projectPath)
    }

    setCurrentSessionId(nil)
    clearPreviewURL()
    refreshCurrentWorkspaceUsage()
    startPreviewObservation()
  }

  public func deleteSession(_ session: StoredSession) async {
    try? await sessionStorage.deleteSession(id: session.id)
    if currentSessionId == session.id {
      setCurrentSessionId(nil)
      chatViewModel?.clearConversation()
    }
    refreshCurrentWorkspaceUsage()
  }

  public func clearActiveWorkspace() {
    previewURLObserver.stopObserving()
    setCurrentSessionId(nil)
    chatViewModel?.clearConversation()
    chatViewModel?.setWorkingDirectory("")
    setCurrentWorkingDirectory(nil)
    clearPreviewURL()
  }

  // MARK: - Preview URL

  public func setPreviewURL(_ url: URL) {
    chatLog.info("Preview URL set: \(url.absoluteString)")
    previewURL = url
    previewURLSource = .appManaged
    // The app now owns the preview. Detected URLs from messages are ignored while
    // app-managed, so stop the message scan loop to avoid pointless per-message rescans.
    previewURLObserver.stopObserving()
  }

  public func setCurrentProject(_ project: EaselDesignProject?) {
    currentProjectLookupTask?.cancel()
    currentProject = project
    currentWorkingDirectory = project?.workingDirectory
    refreshCurrentWorkspaceUsage()
  }

  public func localAgentHandoffContext() -> LocalAgentHandoffContext? {
    guard let currentWorkingDirectory else {
      return nil
    }

    let claudeCommand: String
    if let claudePath = normalized(globalPreferences?.claudePath) {
      claudeCommand = claudePath
    } else {
      claudeCommand = normalized(globalPreferences?.claudeCommand) ?? "claude"
    }

    return LocalAgentHandoffContext(
      easelProjectPath: currentWorkingDirectory,
      codebasePath: normalized(currentProject?.codebasePath),
      project: currentProject,
      previewURL: previewURL,
      claudeCommand: claudeCommand,
      claudeAdditionalPaths: ChatConfiguration.makeDefault().additionalPaths,
      codexCommand: normalized(globalPreferences?.codexCommand) ?? "",
      codexModel: normalized(globalPreferences?.codexModel) ?? "",
      codexExtraArgs: globalPreferences?.codexExtraArgs ?? "",
      codexEnvironmentVariables: globalPreferences?.codexEnvironmentVariables ?? [:]
    )
  }

  // MARK: - Private

  private func startPreviewObservation() {
    previewURLObserver.startObserving(
      messages: { [weak self] in
        self?.chatViewModel?.messages ?? []
      },
      onURLDetected: { [weak self] url in
        chatLog.info("Live observation detected URL: \(url.absoluteString)")
        self?.applyDetectedPreviewURL(url)
      }
    )
  }

  func applyDetectedPreviewURL(_ url: URL) {
    guard previewURLSource != .appManaged else {
      chatLog.info("Ignoring detected preview URL because app-managed preview is active: \(url.absoluteString)")
      return
    }

    previewURL = url
    previewURLSource = .detected
  }

  private func clearPreviewURL() {
    previewURL = nil
    previewURLSource = nil
  }

  private func sendMessageToViewModel(_ text: String, context: String? = nil, hiddenContext: String? = nil) {
    guard let chatViewModel else { return }

    chatViewModel.sendMessage(text, context: context, hiddenContext: hiddenContext)
  }

  func makeHiddenContextForCurrentState(
    _ hiddenContext: String?,
    shouldRecordResourceManifest: Bool = true
  ) -> String {
    let project = resolvedCurrentProject()
    let resourceManifest = projectResourceManifest(at: currentWorkingDirectory)

    if shouldRecordResourceManifest {
      recordResourceManifest(resourceManifest, for: currentWorkingDirectory, sessionId: currentSessionId)
    }

    return EaselAgentInstructions.appendingHiddenContext(
      hiddenContext,
      projectPath: currentWorkingDirectory,
      projectKind: project?.kind,
      projectFidelity: prototypeFidelity(for: project),
      designSystem: project?.designSystem,
      resourcePaths: resourceManifest.map(\.relativePath),
      previewURL: previewURL
    )
  }

  func makeResourceManifestDeltaContextForCurrentState() -> String? {
    guard let workingDirectoryKey = resourceManifestKey(for: currentWorkingDirectory) else {
      return nil
    }

    let currentManifest = projectResourceManifest(at: currentWorkingDirectory)
    let currentFiles = resourceManifestMap(currentManifest)
    guard let sessionId = currentSessionId else {
      pendingResourceManifestByWorkingDirectory[workingDirectoryKey] = currentFiles
      return nil
    }

    let cacheKey = ResourceManifestCacheKey(sessionId: sessionId, workingDirectory: workingDirectoryKey)
    let previousFiles: [String: ProjectResourceFileSignature]
    if let cachedFiles = lastSentResourceManifestBySession[cacheKey] {
      previousFiles = cachedFiles
    } else if let pendingFiles = pendingResourceManifestByWorkingDirectory.removeValue(forKey: workingDirectoryKey) {
      previousFiles = pendingFiles
    } else {
      lastSentResourceManifestBySession[cacheKey] = currentFiles
      return nil
    }

    lastSentResourceManifestBySession[cacheKey] = currentFiles

    let addedPaths = currentFiles.keys
      .filter { previousFiles[$0] == nil }
      .sorted()
    let removedPaths = previousFiles.keys
      .filter { currentFiles[$0] == nil }
      .sorted()
    let updatedPaths = currentFiles.keys
      .filter { path in
        guard let previousSignature = previousFiles[path] else { return false }
        return previousSignature != currentFiles[path]
      }
      .sorted()

    return EaselAgentInstructions.resourceManifestDeltaContext(
      addedPaths: addedPaths,
      updatedPaths: updatedPaths,
      removedPaths: removedPaths
    )
  }

  private func prototypeFidelity(for project: EaselDesignProject?) -> EaselProjectFidelity? {
    guard project?.kind == .prototype else { return nil }
    return project?.fidelity
  }

  private func setCurrentWorkingDirectory(_ path: String?) {
    let normalized = path?.trimmingCharacters(in: .whitespacesAndNewlines)
    currentWorkingDirectory = normalized?.isEmpty == false ? normalized : nil
    currentProject = projectMetadata(at: currentWorkingDirectory)
    refreshCurrentWorkspaceUsage()
    refreshCurrentProjectMetadata(for: currentWorkingDirectory)
  }

  private func refreshCurrentWorkspaceUsage() {
    currentWorkspaceUsageTask?.cancel()

    guard let workingDirectory = currentWorkingDirectory else {
      currentWorkspaceUsageSummary = .zero
      return
    }

    currentWorkspaceUsageTask = Task { [sessionStorage] in
      let summary = (try? await sessionStorage.usageSummaryForWorkingDirectory(workingDirectory)) ?? .zero
      guard !Task.isCancelled else { return }

      await MainActor.run { [weak self] in
        guard self?.currentWorkingDirectory == workingDirectory else { return }
        self?.currentWorkspaceUsageSummary = summary
      }
    }
  }

  private func resolvedCurrentProject() -> EaselDesignProject? {
    if currentProject?.workingDirectory == currentWorkingDirectory {
      return currentProject
    }

    if let project = projectMetadata(at: currentWorkingDirectory) {
      currentProject = project
      return project
    }

    return currentProject
  }

  private func projectMetadata(at workingDirectory: String?) -> EaselDesignProject? {
    guard let workingDirectory, !workingDirectory.isEmpty else { return nil }

    let metadataURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .appendingPathComponent(".easel", isDirectory: true)
      .appendingPathComponent("project.json")

    guard let data = try? Data(contentsOf: metadataURL) else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(EaselDesignProject.self, from: data)
  }

  private func resourceManifestDeltaContextForOutgoingMessage() -> String? {
    guard currentSessionId != nil else {
      recordResourceManifest(projectResourceManifest(at: currentWorkingDirectory), for: currentWorkingDirectory, sessionId: nil)
      return nil
    }

    return makeResourceManifestDeltaContextForCurrentState()
  }

  private func recordResourceManifest(
    _ manifest: [ProjectResourceManifestEntry],
    for workingDirectory: String?,
    sessionId: String?
  ) {
    guard let workingDirectoryKey = resourceManifestKey(for: workingDirectory) else { return }
    let files = resourceManifestMap(manifest)

    if let sessionId {
      let cacheKey = ResourceManifestCacheKey(sessionId: sessionId, workingDirectory: workingDirectoryKey)
      lastSentResourceManifestBySession[cacheKey] = files
      pendingResourceManifestByWorkingDirectory.removeValue(forKey: workingDirectoryKey)
    } else {
      pendingResourceManifestByWorkingDirectory[workingDirectoryKey] = files
    }
  }

  private func resourceManifestMap(
    _ manifest: [ProjectResourceManifestEntry]
  ) -> [String: ProjectResourceFileSignature] {
    Dictionary(uniqueKeysWithValues: manifest.map { ($0.relativePath, $0.signature) })
  }

  private func resourceManifestKey(for workingDirectory: String?) -> String? {
    guard let workingDirectory, !workingDirectory.isEmpty else { return nil }
    return URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .resolvingSymlinksInPath()
      .path
  }

  private func setCurrentSessionId(_ sessionId: String?) {
    currentSessionId = sessionId

    guard let sessionId else { return }
    migratePendingResourceManifest(to: sessionId, workingDirectory: currentWorkingDirectory)
  }

  private func migratePendingResourceManifest(to sessionId: String, workingDirectory: String?) {
    guard let workingDirectoryKey = resourceManifestKey(for: workingDirectory),
          let pendingFiles = pendingResourceManifestByWorkingDirectory.removeValue(forKey: workingDirectoryKey) else {
      return
    }

    let cacheKey = ResourceManifestCacheKey(sessionId: sessionId, workingDirectory: workingDirectoryKey)
    lastSentResourceManifestBySession[cacheKey] = pendingFiles
  }

  private func projectResourceManifest(at workingDirectory: String?) -> [ProjectResourceManifestEntry] {
    guard let workingDirectory, !workingDirectory.isEmpty else { return [] }

    let projectURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .resolvingSymlinksInPath()
    let resourcesURL = projectURL.appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
      at: resourcesURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    var manifest: [ProjectResourceManifestEntry] = []
    for case let fileURL as URL in enumerator {
      guard manifest.count < 80 else { break }

      let values = try? fileURL.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
      )
      guard values?.isRegularFile == true else { continue }

      let filePath = fileURL.resolvingSymlinksInPath().path
      guard filePath.hasPrefix(projectURL.path + "/") else { continue }

      let relativePath = String(filePath.dropFirst(projectURL.path.count + 1))
      manifest.append(ProjectResourceManifestEntry(
        relativePath: relativePath,
        signature: ProjectResourceFileSignature(
          modificationDate: values?.contentModificationDate,
          fileSize: values?.fileSize
        )
      ))
    }

    return manifest.sorted { $0.relativePath < $1.relativePath }
  }

  private func normalized(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  private func refreshCurrentProjectMetadata(for workingDirectory: String?) {
    currentProjectLookupTask?.cancel()

    guard let workingDirectory else {
      currentProject = nil
      return
    }

    if currentProject?.workingDirectory != workingDirectory {
      currentProject = nil
    }
    currentProjectLookupTask = Task { [projectManager] in
      let projects = (try? await projectManager.loadProjects()) ?? []
      let project = projects.first { $0.workingDirectory == workingDirectory }

      guard !Task.isCancelled else { return }

      await MainActor.run { [weak self] in
        guard self?.currentWorkingDirectory == workingDirectory else { return }
        self?.currentProject = project
      }
    }
  }
}

private struct ProjectResourceManifestEntry {
  let relativePath: String
  let signature: ProjectResourceFileSignature
}

private enum PreviewURLSource {
  case appManaged
  case detected
}
