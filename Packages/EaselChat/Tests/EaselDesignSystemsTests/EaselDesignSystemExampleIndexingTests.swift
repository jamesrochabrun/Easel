//
//  EaselDesignSystemExampleIndexingTests.swift
//  EaselChatTests
//

import Testing
@testable import EaselDesignSystems

struct EaselDesignSystemExampleIndexingTests {

  @Test
  func classifiesProductReferencesAndOmitsDocumentationPages() {
    #expect(isHighSignal(title: "Checkout Screen", sourcePage: "Examples"))
    #expect(isHighSignal(title: "Dashboard", sourcePage: "Screens"))
    #expect(isHighSignal(title: "Product Detail", sourcePage: "Flow Templates"))

    #expect(isHighSignal(title: "Button", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "Avatar", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "Action Sheet", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "Page Control", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "app notification", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "Colors", sourcePage: "Design System") == false)
    #expect(isHighSignal(title: "Welcome!", sourcePage: "Welcome") == false)
  }

  private func isHighSignal(title: String, sourcePage: String) -> Bool {
    EaselDesignSystemExampleIndexing.isHighSignalExample(
      title: title,
      sourcePage: sourcePage,
      preview: nil
    )
  }
}
