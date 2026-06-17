//
//  ChatInputView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/7/2025.
//

import SwiftUI
import ClaudeCodeSDK
import UniformTypeIdentifiers

struct ChatInputView: View {
  
  // MARK: - Properties
  
  @Binding var text: String
  @Binding var viewModel: ChatViewModel
  let contextManager: ContextManager
  let uiConfiguration: UIConfiguration
  private let attachmentImportService: any ChatAttachmentImportService
  private let attachmentProcessingService: any AttachmentProcessingService
  
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @Environment(AppearanceSettings.self) private var appearanceSettings
  @Environment(\.colorScheme) private var colorScheme
  
  @FocusState private var isFocused: Bool
  let placeholder: String
  @State private var shouldSubmit = false
  @Binding var triggerFocus: Bool
  @State private var showingDesignSelectionAlert = false
  @State private var attachments: [FileAttachment] = []
  @State private var isDragging = false
  @State private var showingFilePicker = false

  // File search properties
  @State private var showingFileSearch = false
  @State private var fileSearchRange: NSRange? = nil
  @State private var fileSearchViewModel: FileSearchViewModel? = nil
  @State private var fileSearchAnchor: CGPoint = .zero
  @State private var isUpdatingFileSearch = false
  
  // Command search properties
  @State private var showingCommandSearch = false
  @State private var commandSearchRange: NSRange? = nil
  @State private var commandSearchViewModel: CommandSearchViewModel? = nil
  @State private var isUpdatingCommandSearch = false
  
  // MARK: - Constants
  
  private let textAreaEdgeInsets = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 15)
  private let textAreaCornerRadius = 24.0
  
  // MARK: - Initialization
  
  init(
    text: Binding<String>,
    chatViewModel: Binding<ChatViewModel>,
    contextManager: ContextManager,
    uiConfiguration: UIConfiguration = .default,
    placeholder: String = "Message...",
    triggerFocus: Binding<Bool> = .constant(false),
    attachmentImportService: any ChatAttachmentImportService = DefaultChatAttachmentImportService(),
    attachmentProcessingService: any AttachmentProcessingService = AttachmentProcessor())
  {
    _text = text
    _viewModel = chatViewModel
    self.contextManager = contextManager
    self.uiConfiguration = uiConfiguration
    self.placeholder = placeholder
    _triggerFocus = triggerFocus
    self.attachmentImportService = attachmentImportService
    self.attachmentProcessingService = attachmentProcessingService
  }
  // MARK: - Body
  var body: some View {
    VStack(spacing: 0) {
      // File search UI - shown when @ is typed
      if showingFileSearch {
        if let viewModel = fileSearchViewModel {
          InlineFileSearchView(
            viewModel: viewModel,
            onSelect: { result in
              insertFileReference(result)
            },
            onDismiss: {
              dismissFileSearch()
            }
          )
          .background(inlineSearchBackground)
          .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius))
          .overlay(
            RoundedRectangle(cornerRadius: inputCornerRadius)
              .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
          )
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .frame(maxWidth: EaselChatRuntimeStyle.maxContentWidth)
          .frame(maxWidth: .infinity)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
        }
      }
      
      // Command search UI - shown when / is typed at start of message
      if showingCommandSearch {
        if let viewModel = commandSearchViewModel {
          CommandSearchView(
            viewModel: viewModel,
            onSelect: { result in
              insertCommand(result)
            },
            onDismiss: {
              dismissCommandSearch()
            }
          )
          .background(inlineSearchBackground)
          .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius))
          .overlay(
            RoundedRectangle(cornerRadius: inputCornerRadius)
              .stroke(EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: 1)
          )
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
          .frame(maxWidth: EaselChatRuntimeStyle.maxContentWidth)
          .frame(maxWidth: .infinity)
          .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
          ))
        }
      }
      
      // Main input area
      VStack(alignment: .leading, spacing: 7) {
        VStack(alignment: .leading, spacing: 4) {
          if shouldShowContextBar {
            contextBar
          }
          if !attachments.isEmpty {
            AttachmentListView(
              attachments: $attachments,
              attachmentProcessingService: attachmentProcessingService
            )
              .padding(.horizontal, 8)
              .padding(.top, 4)
          }
          HStack(alignment: .bottom, spacing: 8) {
            attachmentButton
            textEditor
            actionButton
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(inputBackground, in: RoundedRectangle(cornerRadius: inputCornerRadius))
        .overlay(inputBorder)
        .onDrop(of: acceptedDropTypes, isTargeted: $isDragging) { providers in
          handleDroppedProviders(providers)
          return true
        }
        
        composerFooter
      }
      .frame(maxWidth: EaselChatRuntimeStyle.maxContentWidth)
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity)
      .background(EaselChatRuntimeStyle.appBackground(for: colorScheme, themeColors: appearanceSettings.themeColors))
    }
    .animation(.easeInOut(duration: 0.2), value: showingFileSearch)
    .animation(.easeInOut(duration: 0.2), value: contextManager.context.codeSelections.count)
    .animation(.easeInOut(duration: 0.2), value: contextManager.context.activeFiles.count)
    .animation(.easeInOut(duration: 0.15), value: viewModel.permissionMode)
    .onChange(of: viewModel.projectPath) { oldValue, newValue in
      if !newValue.isEmpty && newValue != oldValue {
        fileSearchViewModel?.updateProjectPath(newValue)
      }
    }
    .onAppear {
      // Only initialize file search if we don't have one already
      if fileSearchViewModel == nil {
        fileSearchViewModel = FileSearchViewModel(projectPath: viewModel.projectPath)
      }
      // Update project path if it changed
      if !viewModel.projectPath.isEmpty {
        fileSearchViewModel?.updateProjectPath(viewModel.projectPath)
      }
    }
    .alert("No Design Selected", isPresented: $showingDesignSelectionAlert) {
      designSelectionAlertButtons
    } message: {
      Text("Select an existing design or create a new one before sending a message")
    }
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: allowedFileTypes,
      allowsMultipleSelection: true
    ) { result in
      handleFileImport(result)
    }
  }
  
  // MARK: - Computed Properties
}

// MARK: - Main UI Components

extension ChatInputView {
  
  /// Attachment button
  private var attachmentButton: some View {
    Button(action: {
      showingFilePicker = true
    }) {
      Image(systemName: "paperclip")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))
        .frame(width: 28, height: 28)
    }
    .buttonStyle(.plain)
    .help("Attach files")
  }

  /// Action button (send/cancel)
  private var actionButton: some View {
    Group {
      if viewModel.isLoading {
        cancelButton
      } else {
        sendButton
      }
    }
  }
  
  /// Cancel request button
  private var cancelButton: some View {
    Button(action: {
      viewModel.cancelRequest()
    }) {
      Image(systemName: "stop.fill")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(EaselChatRuntimeStyle.userText(for: colorScheme))
        .frame(width: 30, height: 30)
        .background(EaselChatRuntimeStyle.userBubble(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
    }
    .buttonStyle(.plain)
    .help("Stop response")
  }
  
  /// Send message button
  private var sendButton: some View {
    Button(action: {
      sendMessage()
    }) {
      Image(systemName: "arrow.up")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(isTextEmpty ? EaselChatRuntimeStyle.tertiaryText(for: colorScheme) : EaselChatRuntimeStyle.userText(for: colorScheme))
        .frame(width: 30, height: 30)
        .background(
          isTextEmpty
            ? EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme)
            : EaselChatRuntimeStyle.userBubble(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius)
        )
    }
    .buttonStyle(.plain)
    .disabled(isTextEmpty)
    .help("Send message")
  }

  private var composerFooter: some View {
    HStack(spacing: 8) {
      Spacer(minLength: 12)

      #if DEBUG
        if viewModel.activeSessionId != nil || viewModel.currentSessionUsageSummary.hasUsage {
          SessionTokenBadge(summary: viewModel.currentSessionUsageSummary)
        }
      #endif

      if viewModel.activeProvider == .codex {
        CodexModelBadge(modelIdentifier: globalPreferences.codexModel)
      }

      if viewModel.activeProvider != .codex {
        PermissionModeButton(mode: $viewModel.permissionMode)
      }
    }
    .font(.system(size: 10))
    .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))
    .padding(.horizontal, 4)
  }

  private var inputCornerRadius: CGFloat {
    min(CGFloat(uiConfiguration.inputCornerRadius), EaselChatRuntimeStyle.cardRadius)
  }

  private var inputBackground: AnyShapeStyle {
    if uiConfiguration.useMaterialInputBackground {
      return AnyShapeStyle(.thinMaterial)
    }

    return AnyShapeStyle(EaselChatRuntimeStyle.panelBackground(for: colorScheme))
  }

  private var inlineSearchBackground: AnyShapeStyle {
    if uiConfiguration.useMaterialInputBackground {
      return AnyShapeStyle(.regularMaterial)
    }

    return AnyShapeStyle(EaselChatRuntimeStyle.cardBackground(for: colorScheme))
  }
  
  /// Input area border
  private var inputBorder: some View {
    RoundedRectangle(cornerRadius: inputCornerRadius)
      .stroke(isDragging ? EaselChatRuntimeStyle.running : EaselChatRuntimeStyle.border(for: colorScheme), lineWidth: isDragging ? 2 : 1)
      .animation(.easeInOut(duration: 0.2), value: isDragging)
  }
  
  /// Design selection alert buttons
  private var designSelectionAlertButtons: some View {
    Button("Cancel", role: .cancel) {}
  }
  
  /// Placeholder view
  private var placeholderView: some View {
    Text(placeholder)
      .font(.system(size: uiConfiguration.messageFontSize))
      .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))
      .frame(maxWidth: .infinity, alignment: .leading)
      .onTapGesture {
        isFocused = true
      }
  }
}

// MARK: - Text Editor

extension ChatInputView {
  
  /// Main text editor component
  private var textEditor: some View {
    ZStack(alignment: .center) {
      TextEditor(text: $text)
        .scrollContentBackground(.hidden)
        .focused($isFocused)
        .font(.system(size: uiConfiguration.messageFontSize))
        .tint(EaselChatRuntimeStyle.inputTint(for: colorScheme))
        .frame(minHeight: 20, maxHeight: 200)
        .fixedSize(horizontal: false, vertical: true)
        .padding(textAreaEdgeInsets)
        .onAppear {
          isFocused = true
        }
        .onChange(of: triggerFocus) { _, shouldFocus in
          if shouldFocus {
            isFocused = true
            triggerFocus = false
          }
        }
        .onChange(of: text) { oldValue, newValue in
          // Simple check to avoid freezing
          if newValue.count > 1000 {
            print("[ChatInputView] Text too long, skipping @ and / detection")
            return
          }
          detectAtMention(oldText: oldValue, newText: newValue)
          detectSlashCommand(oldText: oldValue, newText: newValue)
        }
        .onKeyPress { key in
          handleKeyPress(key)
        }
      
      if text.isEmpty {
        placeholderView
          .padding(textAreaEdgeInsets)
          .padding(.leading, 4)
      }
    }
  }
  
  /// Handle keyboard events
  private func handleKeyPress(_ key: KeyPress) -> KeyPress.Result {
    // When command search is showing, handle navigation keys
    if showingCommandSearch {
      switch key.key {
      case .return:
        if let result = commandSearchViewModel?.getSelectedResult() {
          insertCommand(result)
        }
        return .handled
      case .escape:
        dismissCommandSearch()
        return .handled
      case .downArrow:
        commandSearchViewModel?.selectNext()
        return .handled
      case .upArrow:
        commandSearchViewModel?.selectPrevious()
        return .handled
      default:
        return .ignored
      }
    }
    // When file search is showing, handle navigation keys
    else if showingFileSearch {
      switch key.key {
      case .return:
        if let result = fileSearchViewModel?.getSelectedResult() {
          insertFileReference(result)
        }
        return .handled
      case .escape:
        dismissFileSearch()
        return .handled
      case .downArrow:
        fileSearchViewModel?.selectNext()
        return .handled
      case .upArrow:
        fileSearchViewModel?.selectPrevious()
        return .handled
      default:
        return .ignored
      }
    } else {
      // Normal text editor behavior
      switch key.key {
      case .return:
        // Check if shift is pressed - if so, allow new line
        if key.modifiers.contains(.shift) {
          // Return .ignored to let TextEditor handle the newline insertion naturally
          return .ignored
        } else {
          // Don't send message if already loading/streaming
          if viewModel.isLoading {
            return .handled  // Prevent any action including new line
          }
          // Send message on regular return (without shift)
          sendMessage()
          return .handled
        }
      case .escape:
        if viewModel.isLoading {
          viewModel.cancelRequest()
          return .handled
        }
        return .ignored
      default:
        return .ignored
      }
    }
  }
}

// MARK: - Context Bar

extension ChatInputView {
  
  /// Context bar showing active file and selections
  private var contextBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        fileChips
        contextDivider
        codeSelectionChips
      }
      .padding(.horizontal, 4)
    }
    .padding(.top, 6)
    .padding(.horizontal, 4)
    .transition(.asymmetric(
      insertion: .move(edge: .top).combined(with: .opacity),
      removal: .move(edge: .top).combined(with: .opacity)
    ))
  }
  
  /// File chips added from local file search.
  private var fileChips: some View {
    ForEach(contextManager.context.activeFiles) { file in
      ActiveFileView(
        model: FileDisplayModel(
          fileName: file.name,
          filePath: file.path,
          lineRange: nil,
          isRemovable: true
        ),
        onRemove: {
          contextManager.removeFile(id: file.id)
        }
      )
    }
  }
  
  /// Divider between active file and selections
  @ViewBuilder
  private var contextDivider: some View {
    if !contextManager.context.activeFiles.isEmpty && !contextManager.context.codeSelections.isEmpty {
      Divider()
        .frame(height: 16)
    }
  }
  
  /// Code selection chips
  private var codeSelectionChips: some View {
    ForEach(contextManager.context.codeSelections) { selection in
      ActiveFileView(
        model: .selection(selection),
        onRemove: {
          contextManager.removeSelection(id: selection.id)
        }
      )
    }
  }
}

// MARK: - Helper Properties

extension ChatInputView {
  
  /// Check if text is empty
  private var isTextEmpty: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  /// Check if context bar should be shown
  private var shouldShowContextBar: Bool {
    !contextManager.context.activeFiles.isEmpty || !contextManager.context.codeSelections.isEmpty
  }
  
  /// Allowed file types for import
  private var allowedFileTypes: [UTType] {
    [.folder, .image, .pdf, .text, .plainText, .sourceCode, .data, .item]
  }

  /// Accepted drag and drop types
  private var acceptedDropTypes: [UTType] {
    attachmentImportService.acceptedContentTypes
  }
  
  /// Trimmed text without whitespace
  private var trimmedText: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// Formatted context from context manager
  private var formattedContext: String? {
    contextManager.hasContext ? contextManager.getFormattedContext() : nil
  }
  
}

// MARK: - Actions

extension ChatInputView {
  
  /// Send message to the chat
  private func sendMessage() {
    guard !trimmedText.isEmpty else { return }
    
    if viewModel.projectPath.isEmpty {
      showingDesignSelectionAlert = true
      return
    }
    
    let codeSelections = contextManager.context.codeSelections.isEmpty ? nil : contextManager.context.codeSelections
    
    // Include attachments if any
    let messageAttachments = attachments.isEmpty ? nil : attachments
    
    viewModel.sendMessage(trimmedText, context: formattedContext, codeSelections: codeSelections, attachments: messageAttachments)
    text = ""
    contextManager.clearAll()
    attachments.removeAll()
  }
}

// MARK: - File Handling

extension ChatInputView {
  
  /// Handle file import from file picker
  private func handleFileImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      importAttachments(from: urls)
    case .failure(let error):
      print("Failed to import files: \(error)")
    }
  }
  
  /// Handle dropped item providers
  private func handleDroppedProviders(_ providers: [NSItemProvider]) {
    Task {
      let importedAttachments = await attachmentImportService.attachments(from: providers)
      await appendAndProcess(importedAttachments)
    }
  }

  private func importAttachments(from urls: [URL]) {
    Task {
      let importedAttachments = await attachmentImportService.attachments(from: urls)
      await appendAndProcess(importedAttachments)
    }
  }

  @MainActor
  private func appendAndProcess(_ importedAttachments: [FileAttachment]) async {
    guard !importedAttachments.isEmpty else { return }

    attachments.append(contentsOf: importedAttachments)
    await attachmentProcessingService.processAttachments(importedAttachments)
  }
}

// MARK: - File Search

extension ChatInputView {
  
  /// Detect @ mention in text and trigger file search
  private func detectAtMention(oldText: String, newText: String) {
    // Prevent recursive updates
    guard !isUpdatingFileSearch else {
      return
    }
    
    // If text was deleted and we're showing search, check if @ was deleted
    if showingFileSearch && newText.count < oldText.count {
      // Check if the @ character is still present at the search location
      if let searchRange = fileSearchRange {
        let nsString = newText as NSString
        if searchRange.location >= nsString.length ||
            (searchRange.location < nsString.length && nsString.character(at: searchRange.location) != 64) { // 64 is @
          dismissFileSearch()
          return
        }
      }
    }
    
    // Check if @ was just typed
    let oldCount = oldText.filter { $0 == "@" }.count
    let newCount = newText.filter { $0 == "@" }.count
    
    if newCount > oldCount {
      // Find the position of the newly typed @
      if let atIndex = findNewAtPosition(oldText: oldText, newText: newText) {
        // Start file search
        fileSearchRange = NSRange(location: atIndex, length: 1)
        showingFileSearch = true
        fileSearchViewModel?.startSearch(query: "")
      }
    } else if showingFileSearch && !newText.isEmpty {
      // Update search query if we're already searching
      updateFileSearchQuery()
    } else if newText.isEmpty && showingFileSearch {
      // All text deleted, dismiss search
      dismissFileSearch()
    }
  }
  
  /// Find position of newly typed @ character
  private func findNewAtPosition(oldText: String, newText: String) -> Int? {
    let oldChars = Array(oldText)
    let newChars = Array(newText)
    
    // Find where the texts differ
    var i = 0
    while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
      i += 1
    }
    
    // Check if @ was inserted at position i
    if i < newChars.count && newChars[i] == "@" {
      return i
    }
    
    return nil
  }
  
  /// Update file search query based on text after @
  private func updateFileSearchQuery() {
    guard let searchRange = fileSearchRange else { return }
    
    // Validate search range
    let nsString = text as NSString
    guard searchRange.location < nsString.length else {
      dismissFileSearch()
      return
    }
    
    // The search range starts at @ character
    let atLocation = searchRange.location
    
    // Find the end of the search query (until space, newline, or end of text)
    var queryEnd = atLocation + 1 // Start after the @ symbol
    while queryEnd < nsString.length {
      let char = nsString.character(at: queryEnd)
      if char == 32 || char == 10 { // space or newline
        break
      }
      queryEnd += 1
    }
    
    // Extract the full query after @ (not including @)
    let queryStart = atLocation + 1
    let queryLength = queryEnd - queryStart
    
    if queryStart <= nsString.length && queryLength >= 0 && queryStart + queryLength <= nsString.length {
      let query = nsString.substring(with: NSRange(location: queryStart, length: queryLength))
      fileSearchViewModel?.searchQuery = query
      
      // Update the search range to include @ and the query
      fileSearchRange = NSRange(location: atLocation, length: queryEnd - atLocation)
    }
  }
  
  /// Insert selected file reference into text
  private func insertFileReference(_ result: FileResult) {
    guard let searchRange = fileSearchRange else { return }
    
    // Validate that the range is still valid
    let nsString = text as NSString
    guard searchRange.location >= 0,
          searchRange.location + searchRange.length <= nsString.length else {
      dismissFileSearch()
      return
    }
    
    // Set flag to prevent onChange from triggering file search
    isUpdatingFileSearch = true
    
    // Replace the @query with @filename
    let replacement = "@\(result.fileName) "
    let newText = nsString.replacingCharacters(in: searchRange, with: replacement)
    text = newText
    
    // Add file to context
    contextManager.addFile(result.fileInfo)
    
    // Dismiss search
    dismissFileSearch()
    
    Task { @MainActor in
      await Task.yield()
      isUpdatingFileSearch = false
    }
  }
  
  /// Dismiss file search and clear state
  private func dismissFileSearch() {
    showingFileSearch = false
    fileSearchRange = nil
    fileSearchViewModel?.clearSearch()
  }
}

// MARK: - Command Search

extension ChatInputView {
  
  /// Detect / at start of message and trigger command search
  private func detectSlashCommand(oldText: String, newText: String) {
    // Prevent recursive updates
    guard !isUpdatingCommandSearch else {
      return
    }
    
    // If text was deleted and we're showing search, check if / was deleted
    if showingCommandSearch && newText.count < oldText.count {
      // Check if the / character is still present at the search location
      if let searchRange = commandSearchRange {
        let nsString = newText as NSString
        if searchRange.location >= nsString.length ||
            (searchRange.location < nsString.length && nsString.character(at: searchRange.location) != 47) { // 47 is /
          dismissCommandSearch()
          return
        }
      }
    }
    
    // Check if / was just typed at the start of the message
    let oldCount = oldText.filter { $0 == "/" }.count
    let newCount = newText.filter { $0 == "/" }.count
    
    if newCount > oldCount {
      // Find the position of the newly typed /
      if let slashIndex = findNewSlashPosition(oldText: oldText, newText: newText) {
        // Only trigger if / is at the start (position 0) or after a newline
        if slashIndex == 0 || (slashIndex > 0 && newText[newText.index(newText.startIndex, offsetBy: slashIndex - 1)] == "\n") {
          // Initialize command search view model if needed
          if commandSearchViewModel == nil {
            commandSearchViewModel = CommandSearchViewModel(projectPath: viewModel.projectPath)
          }
          
          // Start command search
          commandSearchRange = NSRange(location: slashIndex, length: 1)
          showingCommandSearch = true
          commandSearchViewModel?.startSearch(query: "")
        }
      }
    } else if showingCommandSearch && !newText.isEmpty {
      // Update search query if we're already searching
      updateCommandSearchQuery()
    } else if newText.isEmpty && showingCommandSearch {
      // All text deleted, dismiss search
      dismissCommandSearch()
    }
  }
  
  /// Find position of newly typed / character
  private func findNewSlashPosition(oldText: String, newText: String) -> Int? {
    let oldChars = Array(oldText)
    let newChars = Array(newText)
    
    // Find where the texts differ
    var i = 0
    while i < oldChars.count && i < newChars.count && oldChars[i] == newChars[i] {
      i += 1
    }
    
    // Check if / was inserted at position i
    if i < newChars.count && newChars[i] == "/" {
      return i
    }
    
    return nil
  }
  
  /// Update command search query based on text after /
  private func updateCommandSearchQuery() {
    guard let searchRange = commandSearchRange else { return }
    
    // Validate search range
    let nsString = text as NSString
    guard searchRange.location < nsString.length else {
      dismissCommandSearch()
      return
    }
    
    // The search range starts at / character
    let slashLocation = searchRange.location
    
    // Find the end of the search query (until space, newline, or end of text)
    var queryEnd = slashLocation + 1 // Start after the / symbol
    while queryEnd < nsString.length {
      let char = nsString.character(at: queryEnd)
      if char == 32 || char == 10 { // space or newline
        break
      }
      queryEnd += 1
    }
    
    // Extract the full query after / (not including /)
    let queryStart = slashLocation + 1
    let queryLength = queryEnd - queryStart
    
    if queryStart <= nsString.length && queryLength >= 0 && queryStart + queryLength <= nsString.length {
      let query = nsString.substring(with: NSRange(location: queryStart, length: queryLength))
      commandSearchViewModel?.searchQuery = query
      
      // Update the search range to include / and the query
      commandSearchRange = NSRange(location: slashLocation, length: queryEnd - slashLocation)
    }
  }
  
  /// Insert selected command into text
  private func insertCommand(_ result: CommandResult) {
    guard let searchRange = commandSearchRange else { return }
    
    // Validate that the range is still valid
    let nsString = text as NSString
    guard searchRange.location >= 0,
          searchRange.location + searchRange.length <= nsString.length else {
      dismissCommandSearch()
      return
    }
    
    // Set flag to prevent onChange from triggering command search
    isUpdatingCommandSearch = true
    
    // Replace the /query with /command-name followed by space
    let replacement = result.displayName + " "
    let newText = nsString.replacingCharacters(in: searchRange, with: replacement)
    text = newText
    
    // Dismiss search
    dismissCommandSearch()
    
    Task { @MainActor in
      await Task.yield()
      isUpdatingCommandSearch = false
    }
  }
  
  /// Dismiss command search and clear state
  private func dismissCommandSearch() {
    showingCommandSearch = false
    commandSearchRange = nil
    commandSearchViewModel?.clearSearch()
  }

}
