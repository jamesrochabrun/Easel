//
//  ChatServiceTests.swift
//  EaselChatTests
//

import Foundation
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
  func sendMessageWithoutInitializationIsNoOp() {
    let service = ChatService()
    // Should not crash when chatViewModel is nil
    service.sendMessage("test")
    service.sendInspectorPrompt("test")
    service.sendContextPrompt("test")
    service.sendCropPrompt("test")
  }

  @Test
  func appManagedPreviewURLIgnoresDetectedReplacementURL() {
    let service = ChatService()
    service.setPreviewURL(URL(string: "http://localhost:4301/")!)

    service.applyDetectedPreviewURL(URL(string: "http://127.0.0.1:5173/")!)

    #expect(service.previewURL?.absoluteString == "http://localhost:4301/")
  }

  @Test
  func detectedPreviewURLAppliesWhenNoManagedURLExists() {
    let service = ChatService()

    service.applyDetectedPreviewURL(URL(string: "http://127.0.0.1:5173/")!)

    #expect(service.previewURL?.absoluteString == "http://127.0.0.1:5173/")
  }
}
