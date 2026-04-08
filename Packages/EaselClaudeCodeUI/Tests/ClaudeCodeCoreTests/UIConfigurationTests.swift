import XCTest
@testable import ClaudeCodeCore

final class UIConfigurationTests: XCTestCase {

  func testDefaultStylingConfiguration() {
    let configuration = UIConfiguration.default

    XCTAssertEqual(configuration.messageFontSize, 13.0)
    XCTAssertEqual(configuration.inputCornerRadius, 12.0)
    XCTAssertFalse(configuration.useMaterialInputBackground)
    XCTAssertTrue(configuration.showCommandTip)
  }

  func testLibraryStylingConfiguration() {
    let configuration = UIConfiguration.library

    XCTAssertEqual(configuration.messageFontSize, 13.0)
    XCTAssertEqual(configuration.inputCornerRadius, 12.0)
    XCTAssertFalse(configuration.useMaterialInputBackground)
    XCTAssertTrue(configuration.showCommandTip)
  }

  func testCustomStylingConfiguration() {
    let configuration = UIConfiguration(
      appName: "Easel",
      messageFontSize: 14.0,
      inputCornerRadius: 8.0,
      useMaterialInputBackground: true,
      showCommandTip: false
    )

    XCTAssertEqual(configuration.messageFontSize, 14.0)
    XCTAssertEqual(configuration.inputCornerRadius, 8.0)
    XCTAssertTrue(configuration.useMaterialInputBackground)
    XCTAssertFalse(configuration.showCommandTip)
  }
}
