//
//  EaselDesignSystemComponentIndexingTests.swift
//  EaselChatTests
//

import Testing
@testable import EaselDesignSystems

struct EaselDesignSystemComponentIndexingTests {

  @Test
  func classifiesReusableFamiliesAndOmitsLowSignalSingletons() {
    #expect(isHighSignal(title: "Button", category: "Buttons"))
    #expect(isHighSignal(title: "Context Menu (5 Rows)", category: "Navigation"))
    #expect(isHighSignal(title: "List (5 Rows)", category: "Components"))
    #expect(isHighSignal(title: "Page Control (Horizontal)", category: "Components"))

    #expect(isHighSignal(title: "arrow right", category: "Components") == false)
    #expect(isHighSignal(title: "playlist add", category: "Components") == false)
    #expect(isHighSignal(title: "State=Default", category: "Components", properties: [property("State")]) == false)
    #expect(isHighSignal(title: "Content=Actions + Button", category: "Buttons", properties: [property("Content")]) == false)
  }

  private func isHighSignal(
    title: String,
    category: String,
    variantCount: Int = 1,
    properties: [EaselDesignSystemVariantProperty] = []
  ) -> Bool {
    EaselDesignSystemComponentIndexing.isHighSignalFamily(
      title: title,
      category: category,
      variantCount: variantCount,
      variantProperties: properties
    )
  }

  private func property(_ name: String) -> EaselDesignSystemVariantProperty {
    EaselDesignSystemVariantProperty(id: name.lowercased(), name: name, values: ["Default"])
  }
}
