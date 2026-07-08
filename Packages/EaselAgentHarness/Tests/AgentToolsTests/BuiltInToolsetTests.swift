import XCTest
@testable import AgentTools

final class BuiltInToolsetTests: XCTestCase {

  func testToolNamesAreUnique() {
    let tools = BuiltInToolset.makeTools()
    let names = tools.map(\.name)
    XCTAssertEqual(Set(names).count, names.count, "Tool names must be unique")
  }
}
