//
//  DesignMarkdownRoundTripTests.swift
//  EaselDesignSystemsTests
//

import Foundation
import Testing
@testable import EaselDesignSystems

struct DesignMarkdownRoundTripTests {

  /// Once normalized through the emitter, re-parsing and re-emitting must be
  /// stable (idempotent). Asserting on the canonical text sidesteps cosmetic
  /// input differences (quoting, spacing, injected `version`).
  @Test
  func emitterIsIdempotentAfterNormalization() throws {
    let canonical1 = DesignMarkdownEmitter.emit(try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage))
    let canonical2 = DesignMarkdownEmitter.emit(try DesignMarkdownParser.parse(canonical1))
    #expect(canonical1 == canonical2)
  }

  @Test
  func modelSurvivesRoundTrip() throws {
    let normalized = DesignMarkdownEmitter.emit(try DesignMarkdownParser.parse(DesignMarkdownFixtures.heritage))
    let first = try DesignMarkdownParser.parse(normalized)
    let second = try DesignMarkdownParser.parse(DesignMarkdownEmitter.emit(first))
    #expect(first == second)
  }
}
