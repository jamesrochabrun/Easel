//
//  ChatService.swift
//  EaselChat
//

import AgentHarness
import AgentProviderMLX
import AgentProviderOllama
import AgentProviderOpenAI
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

private struct ChatSessionContext {
  let viewModel: ChatViewModel
  let deps: DependencyContainer
  let reference: ChatViewModelReference
}

private enum ChatServiceError: LocalizedError {
  case missingGlobalPreferences
  case backgroundJobsUnsupportedForProvider

  var errorDescription: String? {
    switch self {
    case .missingGlobalPreferences:
      return "Chat service preferences are not initialized."
    case .backgroundJobsUnsupportedForProvider:
      return "Background tweaks aren't supported for the Local / API provider yet — use Send to chat instead."
    }
  }
}

private final class ChatViewModelReference {
  weak var viewModel: ChatViewModel?
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

  /// On-device MLX model management, shared by the chat runtime and the
  /// settings download UI. One instance app-wide — the loaded model is the
  /// process's GPU tenant.
  public let onDeviceModelManager = MLXModelManager()
  @ObservationIgnored private lazy var onDeviceModelRuntime = MLXModelRuntime(manager: onDeviceModelManager)

  /// A model catalog for the settings picker that knows about on-device MLX
  /// models (dispatches `.mlxLocal` profiles to the installed-model list).
  public var apiModelCatalog: any APIModelCatalogProviding {
    APIModelCatalog(clientFactory: apiModelClientFactory)
  }

  /// Model-client factory for the Local / API provider: routes on-device
  /// profiles to MLX and everything else to the HTTP adapters.
  var apiModelClientFactory: @Sendable (EndpointProfile, String?) -> any AgentModelClient {
    let manager = onDeviceModelManager
    let runtime = onDeviceModelRuntime
    return { profile, apiKey in
      switch profile.kind {
      case .mlxLocal:
        return MLXModelClient(profile: profile, runtime: runtime, manager: manager)
      case .ollamaNative:
        return OllamaNativeModelClient(profile: profile)
      case .openAICompatible:
        return OpenAICompatibleModelClient(profile: profile, apiKey: apiKey)
      }
    }
  }

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
  private var sessionContextsById: [String: ChatSessionContext] = [:]
  private var pendingSessionContextsByViewModelId: [ObjectIdentifier: ChatSessionContext] = [:]
  private var sessionIdByViewModelId: [ObjectIdentifier: String] = [:]
  private var activeSessionContext: ChatSessionContext?
  private static let designSystemResourceManifestEntryPaths: Set<String> = [
    "resources/design-system/README.md",
    "resources/design-system/DESIGN.md",
    "resources/design-system/components.md",
    "resources/design-system/examples.md",
    "resources/design-system/assets.md",
    "resources/design-system/catalog.json",
    "resources/design-system/manifest.json",
  ]

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
      let context = try makeSessionContext(globalPreferences: globalPrefs)

      setCurrentWorkingDirectory(context.viewModel.projectPath)

      self.chatViewModel = context.viewModel
      self.deps = context.deps
      self.activeSessionContext = context
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
    sessionContextsById.removeAll()
    pendingSessionContextsByViewModelId.removeAll()
    sessionIdByViewModelId.removeAll()
    activeSessionContext = nil
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
    let initialized = await ensureInitialized()
    guard initialized else { return }

    previewURLObserver.stopObserving()

    // Save current session before switching
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }
    retainCurrentSessionContext()

    // Load fresh session data from storage, fall back to the passed object
    let sessionToLoad: StoredSession
    if let stored = try? await sessionStorage.getSession(id: session.id) {
      sessionToLoad = stored
    } else {
      sessionToLoad = session
    }

    let context: ChatSessionContext
    if let existingContext = sessionContextsById[sessionToLoad.id] {
      context = existingContext
    } else {
      do {
        context = try makeSessionContext(workingDirectory: sessionToLoad.workingDirectory)
      } catch {
        initError = error
        return
      }

      context.viewModel.injectSession(
        sessionId: sessionToLoad.id,
        messages: sessionToLoad.messages,
        workingDirectory: sessionToLoad.workingDirectory,
        provider: sessionToLoad.provider,
        usageSummary: sessionToLoad.usageSummary
      )
      sessionContextsById[sessionToLoad.id] = context
      sessionIdByViewModelId[ObjectIdentifier(context.viewModel)] = sessionToLoad.id
    }

    activateContext(context)

    setCurrentWorkingDirectory(normalized(context.viewModel.projectPath) ?? sessionToLoad.workingDirectory)
    setCurrentSessionId(sessionToLoad.id)
    clearPreviewURL()

    // Immediately scan the active context for a dev server URL. A retained live
    // context can have newer messages than the session snapshot loaded above.
    if let detectedURL = previewURLObserver.scanExistingMessages(context.viewModel.getCurrentMessages()) {
      applyDetectedPreviewURL(detectedURL)
    }

    startPreviewObservation()
  }

  public func startNewSession(workingDirectory: String?) async {
    let initialized = await ensureInitialized()
    guard initialized else { return }

    previewURLObserver.stopObserving()

    // Save current session before starting new one
    if let currentId = currentSessionId, let vm = chatViewModel {
      let messages = vm.getCurrentMessages()
      if !messages.isEmpty {
        try? await sessionStorage.updateSessionMessages(id: currentId, messages: messages)
      }
    }
    retainCurrentSessionContext()

    let context: ChatSessionContext
    do {
      context = try makeSessionContext(workingDirectory: workingDirectory)
    } catch {
      initError = error
      return
    }

    activateContext(context)
    pendingSessionContextsByViewModelId[ObjectIdentifier(context.viewModel)] = context

    // Set the working directory for the new chat
    setCurrentWorkingDirectory(normalized(workingDirectory) ?? context.viewModel.projectPath)

    setCurrentSessionId(nil)
    clearPreviewURL()
    refreshCurrentWorkspaceUsage()
    startPreviewObservation()
  }

  public func deleteSession(_ session: StoredSession) async {
    try? await sessionStorage.deleteSession(id: session.id)
    if let context = sessionContextsById.removeValue(forKey: session.id) {
      sessionIdByViewModelId.removeValue(forKey: ObjectIdentifier(context.viewModel))
      if activeSessionContext?.viewModel === context.viewModel {
        activeSessionContext = nil
      }
      if !isVisibleViewModel(context.viewModel) {
        context.viewModel.clearConversation()
      }
    }

    if currentSessionId == session.id {
      activeSessionContext = nil
      setCurrentSessionId(nil)
      chatViewModel?.clearConversation()
    }
    refreshCurrentWorkspaceUsage()
  }

  public func clearActiveWorkspace() {
    previewURLObserver.stopObserving()
    let retainedContexts = Array(sessionContextsById.values) + Array(pendingSessionContextsByViewModelId.values)
    for context in retainedContexts {
      if isVisibleViewModel(context.viewModel) { continue }
      context.viewModel.clearConversation()
    }
    sessionContextsById.removeAll()
    pendingSessionContextsByViewModelId.removeAll()
    sessionIdByViewModelId.removeAll()
    activeSessionContext = nil
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

  // MARK: - Background Jobs

  /// True when any retained session context working in `workingDirectory`
  /// has a turn in flight — including sessions the user switched away from.
  public func isAnySessionBusy(workingDirectory: String) -> Bool {
    let target = Self.normalizedPath(workingDirectory)
    var viewModels: [ChatViewModel] = []
    if let chatViewModel {
      viewModels.append(chatViewModel)
    }
    viewModels.append(contentsOf: sessionContextsById.values.map(\.viewModel))
    viewModels.append(contentsOf: pendingSessionContextsByViewModelId.values.map(\.viewModel))

    return viewModels.contains { viewModel in
      viewModel.isLoading && Self.normalizedPath(viewModel.projectPath) == target
    }
  }

  /// Builds the background job service wired to the active provider's
  /// preferences and this service's busy state.
  public func makeBackgroundJobService(validator: any BackgroundJobValidating) -> BackgroundAgentJobService {
    BackgroundAgentJobService(
      runnerProvider: { [weak self] in
        guard let self, let preferences = self.globalPreferences else {
          throw ChatServiceError.missingGlobalPreferences
        }
        return try self.makeBackgroundRunner(preferences: preferences)
      },
      validator: validator,
      isChatBusy: { [weak self] projectPath in
        self?.isAnySessionBusy(workingDirectory: projectPath) ?? false
      }
    )
  }

  /// Resolved fresh at each job start so provider/model switches are honored.
  private func makeBackgroundRunner(preferences: GlobalPreferencesStorage) throws -> any BackgroundAgentRunning {
    switch preferences.chatProvider {
    case .api:
      // The Local / API provider runs an in-process harness, not a CLI —
      // no headless runner yet. The failed pill offers "Send to chat",
      // which works with this provider.
      throw ChatServiceError.backgroundJobsUnsupportedForProvider

    case .claude:
      var configuration = ChatConfiguration.makeDefault()
      if let claudePath = normalized(preferences.claudePath) {
        configuration.command = claudePath
      } else if let claudeCommand = normalized(preferences.claudeCommand) {
        configuration.command = claudeCommand
      }
      return ClaudeBackgroundAgentRunner(
        baseConfiguration: configuration,
        model: normalized(preferences.claudeModel),
        appendSystemPrompt: EaselAgentInstructions.systemPromptPrefix
      )

    case .codex:
      return CodexBackgroundAgentRunner(
        commandOverride: normalized(preferences.codexCommand),
        environmentOverrides: preferences.codexEnvironmentVariables,
        model: normalized(preferences.codexModel),
        extraArguments: CodexClientFactory.parseArgumentString(preferences.codexExtraArgs)
      )
    }
  }

  private static func normalizedPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
  }

  // MARK: - Private

  private func ensureInitialized() async -> Bool {
    if !isInitialized {
      await initialize()
    }

    return isInitialized
  }

  private func makeSessionContext(
    globalPreferences preferences: GlobalPreferencesStorage? = nil,
    workingDirectory: String? = nil
  ) throws -> ChatSessionContext {
    guard let preferences = preferences ?? globalPreferences else {
      throw ChatServiceError.missingGlobalPreferences
    }

    let container = DependencyContainer(
      globalPreferences: preferences,
      customSessionStorage: sessionStorage,
      mcpToolsDiscovery: mcpToolsDiscovery,
      logger: logger
    )

    var config = ChatConfiguration.makeDefault()
    config.command = preferences.claudeCommand

    if let workingDirectory = normalized(workingDirectory) {
      config.workingDirectory = workingDirectory
      container.settingsStorage.setProjectPath(workingDirectory)
    } else if let workingDirectory = normalized(config.workingDirectory) {
      container.settingsStorage.setProjectPath(workingDirectory)
    }

    let client = try ClaudeCodeClient(configuration: config)
    let reference = ChatViewModelReference()
    let viewModel = ChatViewModel(
      claudeClient: client,
      sessionStorage: sessionStorage,
      settingsStorage: container.settingsStorage,
      globalPreferences: preferences,
      customPermissionService: container.customPermissionService,
      mcpToolsDiscovery: mcpToolsDiscovery,
      logger: logger,
      systemPromptPrefix: EaselAgentInstructions.systemPromptPrefix,
      codexDeveloperInstructionsPrefix: EaselAgentInstructions.codexDeveloperInstructionsPrefix,
      apiInstructionsPrefix: EaselAgentInstructions.apiAgentInstructionsPrefix,
      apiModelClientFactory: apiModelClientFactory,
      shouldManageSessions: true,
      onSessionChange: { [weak self, weak reference] newSessionId in
        Task { @MainActor in
          guard let viewModel = reference?.viewModel else { return }
          self?.handleSessionChange(newSessionId, from: viewModel)
        }
      },
      onSessionUsageChange: { [weak self, weak reference] _ in
        Task { @MainActor in
          guard let self else { return }
          if self.isVisibleViewModel(reference?.viewModel) {
            self.refreshCurrentWorkspaceUsage()
          }
          self.onSessionChanged?()
        }
      }
    )
    reference.viewModel = viewModel

    viewModel.runtimeHiddenContextProvider = { [weak self, weak viewModel] in
      self?.makeHiddenContext(for: viewModel, hiddenContext: nil)
    }
    viewModel.outgoingHiddenContextProvider = { [weak self, weak viewModel] in
      self?.resourceManifestDeltaContextForOutgoingMessage(from: viewModel)
    }

    return ChatSessionContext(viewModel: viewModel, deps: container, reference: reference)
  }

  private func retainCurrentSessionContext() {
    guard let chatViewModel,
          let context = activeSessionContext,
          context.viewModel === chatViewModel else { return }

    let viewModelId = ObjectIdentifier(chatViewModel)
    if let sessionId = currentSessionId ?? sessionIdByViewModelId[viewModelId] {
      sessionContextsById[sessionId] = context
      sessionIdByViewModelId[viewModelId] = sessionId
    } else if chatViewModel.isLoading || !chatViewModel.messages.isEmpty {
      pendingSessionContextsByViewModelId[viewModelId] = context
    }
  }

  private func context(for viewModel: ChatViewModel) -> ChatSessionContext? {
    let viewModelId = ObjectIdentifier(viewModel)
    if let sessionId = sessionIdByViewModelId[viewModelId],
       let context = sessionContextsById[sessionId] {
      return context
    }

    if let context = pendingSessionContextsByViewModelId[viewModelId] {
      return context
    }

    if chatViewModel === viewModel,
       let activeSessionContext,
       activeSessionContext.viewModel === viewModel {
      return activeSessionContext
    }

    return nil
  }

  private func activateContext(_ context: ChatSessionContext) {
    chatViewModel = context.viewModel
    deps = context.deps
    activeSessionContext = context
  }

  private func handleSessionChange(_ sessionId: String, from viewModel: ChatViewModel) {
    guard let context = context(for: viewModel) else { return }

    let viewModelId = ObjectIdentifier(viewModel)
    pendingSessionContextsByViewModelId.removeValue(forKey: viewModelId)
    sessionContextsById[sessionId] = context
    sessionIdByViewModelId[viewModelId] = sessionId

    guard isVisibleViewModel(viewModel) else {
      onSessionChanged?()
      return
    }

    setCurrentSessionId(sessionId)
    setCurrentWorkingDirectory(viewModel.projectPath)
    refreshCurrentWorkspaceUsage()
    onSessionChanged?()
  }

  private func isVisibleViewModel(_ viewModel: ChatViewModel?) -> Bool {
    guard let viewModel, let chatViewModel else { return false }
    return chatViewModel === viewModel
  }

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
    makeHiddenContext(
      hiddenContext,
      workingDirectory: currentWorkingDirectory,
      sessionId: currentSessionId,
      shouldRecordResourceManifest: shouldRecordResourceManifest
    )
  }

  private func makeHiddenContext(
    for viewModel: ChatViewModel?,
    hiddenContext: String?,
    shouldRecordResourceManifest: Bool = true
  ) -> String {
    let viewModelId = viewModel.map { ObjectIdentifier($0) }
    let workingDirectory = normalized(viewModel?.projectPath) ?? currentWorkingDirectory
    let sessionId = viewModelId.flatMap { sessionIdByViewModelId[$0] } ?? (isVisibleViewModel(viewModel) ? currentSessionId : nil)

    return makeHiddenContext(
      hiddenContext,
      workingDirectory: workingDirectory,
      sessionId: sessionId,
      shouldRecordResourceManifest: shouldRecordResourceManifest
    )
  }

  private func makeHiddenContext(
    _ hiddenContext: String?,
    workingDirectory: String?,
    sessionId: String?,
    shouldRecordResourceManifest: Bool
  ) -> String {
    let project = projectMetadata(at: workingDirectory) ?? (workingDirectory == currentWorkingDirectory ? resolvedCurrentProject() : nil)
    let resourceManifest = projectResourceManifest(at: workingDirectory)

    if shouldRecordResourceManifest {
      recordResourceManifest(resourceManifest, for: workingDirectory, sessionId: sessionId)
    }

    return EaselAgentInstructions.appendingHiddenContext(
      hiddenContext,
      projectPath: workingDirectory,
      projectKind: project?.kind,
      projectFidelity: prototypeFidelity(for: project),
      designSystem: project?.designSystem,
      designSystemAssetCount: designSystemAssetCount(at: workingDirectory),
      resourcePaths: resourceManifest.map(\.relativePath),
      previewURL: previewURL
    )
  }

  private func designSystemAssetCount(at workingDirectory: String?) -> Int {
    guard let workingDirectory, !workingDirectory.isEmpty else { return 0 }

    let manifestURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .appendingPathComponent(ProjectResource.resourcesDirectoryName, isDirectory: true)
      .appendingPathComponent("design-system", isDirectory: true)
      .appendingPathComponent("manifest.json")

    guard let data = try? Data(contentsOf: manifestURL) else { return 0 }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return (try? decoder.decode(DesignSystemResourcePackManifest.self, from: data))?.assetCount ?? 0
  }

  func makeResourceManifestDeltaContextForCurrentState() -> String? {
    makeResourceManifestDeltaContext(
      workingDirectory: currentWorkingDirectory,
      sessionId: currentSessionId
    )
  }

  private func resourceManifestDeltaContextForOutgoingMessage(from viewModel: ChatViewModel?) -> String? {
    let viewModelId = viewModel.map { ObjectIdentifier($0) }
    let workingDirectory = normalized(viewModel?.projectPath) ?? currentWorkingDirectory
    let sessionId = viewModelId.flatMap { sessionIdByViewModelId[$0] } ?? (isVisibleViewModel(viewModel) ? currentSessionId : nil)

    guard sessionId != nil else {
      recordResourceManifest(projectResourceManifest(at: workingDirectory), for: workingDirectory, sessionId: nil)
      return nil
    }

    return makeResourceManifestDeltaContext(
      workingDirectory: workingDirectory,
      sessionId: sessionId
    )
  }

  private func makeResourceManifestDeltaContext(
    workingDirectory: String?,
    sessionId: String?
  ) -> String? {
    guard let workingDirectoryKey = resourceManifestKey(for: workingDirectory) else {
      return nil
    }

    let currentManifest = projectResourceManifest(at: workingDirectory)
    let currentFiles = resourceManifestMap(currentManifest)
    guard let sessionId else {
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
      let values = try? fileURL.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
      )
      guard values?.isRegularFile == true else { continue }

      let filePath = fileURL.resolvingSymlinksInPath().path
      guard filePath.hasPrefix(projectURL.path + "/") else { continue }

      let relativePath = String(filePath.dropFirst(projectURL.path.count + 1))
      guard shouldIncludeResourceManifestPath(relativePath) else { continue }
      guard manifest.count < 80 else { break }

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

  private func shouldIncludeResourceManifestPath(_ relativePath: String) -> Bool {
    if relativePath.hasPrefix("resources/design-system/") {
      return Self.designSystemResourceManifestEntryPaths.contains(relativePath)
    }
    return true
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

      // Re-embed the attached design system's assets if it changed since the pack
      // was last written. Cheap no-op when nothing changed; only rewrites the
      // design-system-owned pack folder. Any rewritten pack files are reported to
      // the agent through the normal resource-manifest delta on the next message.
      if let project, project.designSystem.kind == .custom {
        _ = try? await projectManager.refreshDesignSystemResources(for: project)
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
