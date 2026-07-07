import AgentHarness
import Foundation
import XCTest
@testable import ClaudeCodeCore

final class APIProviderSettingsTests: XCTestCase {

  // MARK: - GeneralPreferences round trip

  func testGeneralPreferencesRoundTripsAPIFields() throws {
    let profiles = EndpointProfile.builtInPresets()
    let preferences = GeneralPreferences(
      apiEndpointProfiles: profiles,
      selectedAPIProfileId: profiles[0].id,
      apiModel: "qwen3-coder:30b",
      apiMaxTurns: 35
    )

    let data = try JSONEncoder().encode(preferences)
    let decoded = try JSONDecoder().decode(GeneralPreferences.self, from: data)

    XCTAssertEqual(decoded.apiEndpointProfiles, profiles)
    XCTAssertEqual(decoded.selectedAPIProfileId, profiles[0].id)
    XCTAssertEqual(decoded.apiModel, "qwen3-coder:30b")
    XCTAssertEqual(decoded.apiMaxTurns, 35)
  }

  func testOldPreferencesJSONWithoutAPIFieldsDecodesWithDefaults() throws {
    // Simulate a real pre-update preferences file: everything current minus
    // the four new API keys.
    let data = try JSONEncoder().encode(GeneralPreferences())
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for key in ["apiEndpointProfiles", "selectedAPIProfileId", "apiModel", "apiMaxTurns"] {
      json.removeValue(forKey: key)
    }
    let legacyData = try JSONSerialization.data(withJSONObject: json)
    let decoded = try JSONDecoder().decode(GeneralPreferences.self, from: legacyData)
    XCTAssertTrue(decoded.apiEndpointProfiles.isEmpty)
    XCTAssertEqual(decoded.selectedAPIProfileId, "")
    XCTAssertEqual(decoded.apiModel, "")
    XCTAssertEqual(decoded.apiMaxTurns, 20)
  }

  // MARK: - Seeding

  func testSeedingEmptyProfilesInstallsPresetsAndSelectsOllama() {
    let seeded = GlobalPreferencesStorage.seededAPIProfiles(profiles: [], selectedId: "")
    XCTAssertEqual(seeded.profiles, EndpointProfile.builtInPresets())
    let selected = seeded.profiles.first { $0.id == seeded.selectedId }
    XCTAssertEqual(selected?.kind, .ollamaNative)
  }

  func testSeedingRepairsDanglingSelection() {
    let profiles = EndpointProfile.builtInPresets()
    let seeded = GlobalPreferencesStorage.seededAPIProfiles(profiles: profiles, selectedId: "gone")
    XCTAssertEqual(seeded.profiles, profiles)
    XCTAssertTrue(seeded.profiles.contains { $0.id == seeded.selectedId })
  }

  func testSeedingKeepsValidSelection() {
    let profiles = EndpointProfile.builtInPresets()
    let groq = profiles.first { $0.id == "preset-groq" }!
    let seeded = GlobalPreferencesStorage.seededAPIProfiles(profiles: profiles, selectedId: groq.id)
    XCTAssertEqual(seeded.selectedId, groq.id)
  }

  // MARK: - APIModelCatalog

  private final class CountingClient: AgentModelClient, @unchecked Sendable {
    let capabilities = ModelCapabilities()
    let models: [AgentModelInfo]
    private let lock = NSLock()
    private var _calls = 0

    init(models: [AgentModelInfo]) {
      self.models = models
    }

    var calls: Int {
      lock.lock()
      defer { lock.unlock() }
      return _calls
    }

    private func bump() {
      lock.lock()
      _calls += 1
      lock.unlock()
    }

    func streamCompletion(_ request: AgentModelRequest) async throws -> AsyncThrowingStream<AgentModelEvent, Error> {
      AsyncThrowingStream { $0.finish() }
    }

    func listModels() async throws -> [AgentModelInfo] {
      bump()
      return models
    }
  }

  func testCatalogListsAndCaches() async throws {
    let client = CountingClient(models: [AgentModelInfo(id: "m1"), AgentModelInfo(id: "m2")])
    let catalog = APIModelCatalog(cacheLifetime: 60) { _, _ in client }
    let profile = EndpointProfile.builtInPresets().first { $0.kind == .ollamaNative }!

    let first = try await catalog.availableModels(profile: profile, apiKey: nil)
    let second = try await catalog.availableModels(profile: profile, apiKey: nil)

    XCTAssertEqual(first.map(\.id), ["m1", "m2"])
    XCTAssertEqual(second.map(\.id), ["m1", "m2"])
    XCTAssertEqual(client.calls, 1, "second lookup must hit the cache")
  }

  func testCatalogListsMLXFromClientAndBypassesCache() async throws {
    // On-device models change as the user downloads/deletes them, so MLX must
    // always query the client (installed-model list), never serve a cached set.
    let client = CountingClient(models: [AgentModelInfo(id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit")])
    let catalog = APIModelCatalog(cacheLifetime: 60) { _, _ in client }
    let mlx = EndpointProfile.builtInPresets().first { $0.kind == .mlxLocal }!

    let first = try await catalog.availableModels(profile: mlx, apiKey: nil)
    let second = try await catalog.availableModels(profile: mlx, apiKey: nil)

    XCTAssertEqual(first.map(\.id), ["mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"])
    XCTAssertEqual(second.map(\.id), first.map(\.id))
    XCTAssertEqual(client.calls, 2, "MLX must not be cached — each lookup re-queries installed models")
  }

  // MARK: - Keychain credential store

  func testKeychainStoreRoundTripAndDelete() throws {
    let store = KeychainCredentialStore(service: "com.easel.api-provider.tests")
    let profileId = "test-profile-\(UUID().uuidString)"
    defer { try? store.setAPIKey(nil, for: profileId) }

    do {
      try store.setAPIKey("sk-first", for: profileId)
    } catch {
      throw XCTSkip("Keychain unavailable in this test environment: \(error)")
    }

    XCTAssertEqual(try store.apiKey(for: profileId), "sk-first")

    // Update-in-place
    try store.setAPIKey("sk-second", for: profileId)
    XCTAssertEqual(try store.apiKey(for: profileId), "sk-second")

    // nil deletes
    try store.setAPIKey(nil, for: profileId)
    XCTAssertNil(try store.apiKey(for: profileId))

    // deleting again is not an error
    XCTAssertNoThrow(try store.setAPIKey(nil, for: profileId))
  }

  func testInMemoryStoreMatchesProtocolSemantics() throws {
    let store = InMemoryCredentialStore()
    XCTAssertNil(try store.apiKey(for: "p"))
    try store.setAPIKey("k", for: "p")
    XCTAssertEqual(try store.apiKey(for: "p"), "k")
    try store.setAPIKey(nil, for: "p")
    XCTAssertNil(try store.apiKey(for: "p"))
  }
}
