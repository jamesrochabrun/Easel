import XCTest
import AgentHarness
@testable import AgentProviderOllama

final class OllamaClientContractTests: XCTestCase {

  func testCapabilitiesComeFromProfile() {
    let profile = EndpointProfile.builtInPresets().first { $0.kind == .ollamaNative }!
    let client = OllamaNativeModelClient(profile: profile)
    XCTAssertEqual(client.capabilities, profile.capabilities)
    XCTAssertFalse(client.capabilities.supportsParallelToolCalls)
  }
}
