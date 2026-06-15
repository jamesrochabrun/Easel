//
//  CodexCommandResolverTests.swift
//  ClaudeCodeCoreTests
//

import XCTest
@testable import ClaudeCodeCore

final class CodexCommandResolverTests: XCTestCase {
  private var temporaryHome: URL!

  override func setUpWithError() throws {
    temporaryHome = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexCommandResolverTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    if let temporaryHome {
      try? FileManager.default.removeItem(at: temporaryHome)
    }
    temporaryHome = nil
  }

  func testOverrideWinsWithoutFilesystemValidation() throws {
    let resolver = makeResolver()

    let resolution = try XCTUnwrap(resolver.resolve(commandOverride: " /custom/bin/codex "))

    XCTAssertEqual(resolution.path, "/custom/bin/codex")
    XCTAssertEqual(resolution.source, .override)
  }

  func testLocalCodexInstallWinsOverOtherCandidates() throws {
    try makeExecutable(".codex/local/codex")
    try makeExecutable(".npm-global/bin/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".codex/local/codex"))
    XCTAssertEqual(resolution.source, .localInstall)
  }

  func testFindsStandaloneInstallerDefaultLocation() throws {
    try makeExecutable(".local/bin/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".local/bin/codex"))
    XCTAssertEqual(resolution.source, .localInstall)
  }

  func testFindsUserNpmGlobalInstallUsedByThisMachine() throws {
    try makeExecutable(".npm-global/bin/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".npm-global/bin/codex"))
    XCTAssertEqual(resolution.source, .npmGlobal)
  }

  func testFindsCurrentNvmInstall() throws {
    try makeExecutable(".nvm/current/bin/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".nvm/current/bin/codex"))
    XCTAssertEqual(resolution.source, .nvm)
  }

  func testFindsNewestNvmVersionInstall() throws {
    try makeExecutable(".nvm/versions/node/v18.19.0/bin/codex")
    try makeExecutable(".nvm/versions/node/v22.16.0/bin/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".nvm/versions/node/v22.16.0/bin/codex"))
    XCTAssertEqual(resolution.source, .nvm)
  }

  func testNvmVersionInstallWinsOverHomebrewFallback() throws {
    try makeExecutable(".nvm/versions/node/v22.16.0/bin/codex")
    try makeExecutable("homebrew/bin/codex")
    let resolver = makeResolver(homebrewDirectories: [path("homebrew/bin")])

    let resolution = try XCTUnwrap(resolver.resolve())

    XCTAssertEqual(resolution.path, path(".nvm/versions/node/v22.16.0/bin/codex"))
    XCTAssertEqual(resolution.source, .nvm)
  }

  func testFindsToolShimInstall() throws {
    try makeExecutable(".local/share/mise/shims/codex")

    let resolution = try XCTUnwrap(makeResolver().resolve())

    XCTAssertEqual(resolution.path, path(".local/share/mise/shims/codex"))
    XCTAssertEqual(resolution.source, .toolShim)
  }

  func testFindsPathOnlyInstallAndExpandsTilde() throws {
    try makeExecutable("custom-bin/codex")
    let resolver = makeResolver(pathEnvironment: "~/custom-bin")

    let resolution = try XCTUnwrap(resolver.resolve())

    XCTAssertEqual(resolution.path, path("custom-bin/codex"))
    XCTAssertEqual(resolution.source, .path)
  }

  func testPathInstallWinsOverHomebrewFallback() throws {
    try makeExecutable("custom-bin/codex")
    try makeExecutable("homebrew/bin/codex")
    let resolver = makeResolver(
      pathEnvironment: "~/custom-bin",
      homebrewDirectories: [path("homebrew/bin")]
    )

    let resolution = try XCTUnwrap(resolver.resolve())

    XCTAssertEqual(resolution.path, path("custom-bin/codex"))
    XCTAssertEqual(resolution.source, .path)
  }

  func testSDKDetectorWinsOverHomebrewFallback() throws {
    try makeExecutable("sdk/bin/codex")
    try makeExecutable("homebrew/bin/codex")
    let resolver = makeResolver(
      homebrewDirectories: [path("homebrew/bin")],
      sdkDetector: { self.path("sdk/bin/codex") }
    )

    let resolution = try XCTUnwrap(resolver.resolve())

    XCTAssertEqual(resolution.path, path("sdk/bin/codex"))
    XCTAssertEqual(resolution.source, .sdkDetector)
  }

  func testFindsHomebrewInstallAsFallback() throws {
    try makeExecutable("homebrew/bin/codex")
    let resolver = makeResolver(homebrewDirectories: [path("homebrew/bin")])

    let resolution = try XCTUnwrap(resolver.resolve())

    XCTAssertEqual(resolution.path, path("homebrew/bin/codex"))
    XCTAssertEqual(resolution.source, .homebrew)
  }

  func testSearchPathDirectoriesIncludeUserNpmGlobalAndIncomingPath() throws {
    let homebrewDirectory = path("homebrew/bin")
    let resolver = makeResolver(
      pathEnvironment: "/tmp/custom:\(homebrewDirectory)",
      homebrewDirectories: [homebrewDirectory]
    )

    let directories = resolver.searchPathDirectories()

    XCTAssertTrue(directories.contains(path(".npm-global/bin")))
    XCTAssertTrue(directories.contains("/tmp/custom"))
    XCTAssertEqual(directories.filter { $0 == homebrewDirectory }.count, 1)
    XCTAssertLessThan(
      try XCTUnwrap(directories.firstIndex(of: "/tmp/custom")),
      try XCTUnwrap(directories.firstIndex(of: homebrewDirectory))
    )
  }

  private func makeResolver(
    pathEnvironment: String? = nil,
    homebrewDirectories: [String] = [],
    sdkDetector: @escaping () -> String? = { nil }
  ) -> CodexCommandResolver {
    CodexCommandResolver(
      homeDirectory: temporaryHome.path,
      pathEnvironment: pathEnvironment,
      homebrewDirectories: homebrewDirectories,
      sdkDetector: sdkDetector
    )
  }

  private func makeExecutable(_ relativePath: String) throws {
    let url = temporaryHome.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try "#!/bin/sh\n".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: url.path
    )
  }

  private func path(_ relativePath: String) -> String {
    temporaryHome.appendingPathComponent(relativePath).path
  }
}
