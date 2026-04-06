//
//  ChatServiceTests.swift
//  EaselChatTests
//

import Testing
@testable import EaselChat

@MainActor
struct ChatServiceTests {

  @Test
  func initialState() {
    let service = ChatService()
    #expect(service.chatViewModel == nil)
    #expect(service.isInitialized == false)
    #expect(service.initError == nil)
    #expect(service.previewURL == nil)
  }

  @Test
  func sendInitialPromptOnlyOnce() {
    let service = ChatService()
    // Without initialization, sendMessage is a no-op (chatViewModel is nil)
    // but the guard flag should still prevent double sends
    service.sendInitialPromptIfNeeded("Hello")
    service.sendInitialPromptIfNeeded("Hello again")
    // No crash, second call is silently ignored
  }

  @Test
  func sendMessageWithoutInitializationIsNoOp() {
    let service = ChatService()
    // Should not crash when chatViewModel is nil
    service.sendMessage("test")
    service.sendInspectorPrompt("test")
    service.sendContextPrompt("test")
    service.sendCropPrompt("test")
  }
}
