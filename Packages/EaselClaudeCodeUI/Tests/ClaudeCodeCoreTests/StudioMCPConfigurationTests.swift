import CodexSDK
import Foundation
import Testing

@testable import ClaudeCodeCore

@MainActor
@Suite("Studio MCP wiring")
struct StudioMCPConfigurationTests {
  private let config = StudioMCPConfiguration(
    serverPath: "/Applications/Easel.app/Contents/Resources/EaselMCPServer",
    projectPath: "/Users/me/Documents/Easel Projects/demo",
    appSupportDirectory: "/Users/me/Library/Application Support/Easel",
    agentGuidance: "Use the Studio tools."
  )

  @Test("Environment carries provider, project, support dir; session id only when known")
  func environment() {
    let withSession = config.environment(provider: "codex", sessionId: "abc")
    #expect(withSession["EASEL_PROVIDER"] == "codex")
    #expect(withSession["EASEL_PROJECT_PATH"] == "/Users/me/Documents/Easel Projects/demo")
    #expect(withSession["EASEL_APP_SUPPORT_DIR"] == "/Users/me/Library/Application Support/Easel")
    #expect(withSession["EASEL_SESSION_ID"] == "abc")

    let firstTurn = config.environment(provider: "claude", sessionId: nil)
    #expect(firstTurn["EASEL_SESSION_ID"] == nil)
  }

  @Test("Codex options attach the server and the auto-approval override on EVERY turn")
  func codexOptionsEveryTurn() {
    for isFirstTurn in [true, false] {
      let options = CodexChatRuntime.makeOptions(
        isFirstTurn: isFirstTurn,
        currentSessionId: isFirstTurn ? nil : "session-9",
        workingDirectory: "/tmp/p",
        studioMCP: config
      )
      let server = options.mcpServers?[StudioMCPConfiguration.serverName]
      #expect(server?.command == config.serverPath, "turn firstTurn=\(isFirstTurn)")
      #expect(server?.args == ["mcp-server"])
      #expect(server?.env?["EASEL_PROVIDER"] == "codex")
      // Under approval=never an unapproved MCP tool call fails hard.
      #expect(options.configOverrides["mcp_servers.easel.default_tools_approval_mode"] == "\"auto\"")
      if !isFirstTurn {
        #expect(server?.env?["EASEL_SESSION_ID"] == "session-9")
      }
    }
  }

  @Test("Codex options without Studio stay untouched")
  func codexOptionsWithoutStudio() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/p"
    )
    #expect(options.mcpServers == nil)
    #expect(options.configOverrides["mcp_servers.easel.default_tools_approval_mode"] == nil)
  }

  @Test("Codex debug command names the Studio server")
  func debugDescriptionShowsServer() {
    let options = CodexChatRuntime.makeOptions(
      isFirstTurn: true,
      currentSessionId: nil,
      workingDirectory: "/tmp/p",
      studioMCP: config
    )
    let description = CodexChatRuntime.debugCommandDescription(options: options)
    #expect(description.contains("mcp_servers.easel.command"))
  }

  @Test("Merger injects the easel server and keeps the user's servers")
  func mergerKeepsUserServers() throws {
    let userConfig = """
      {"mcpServers": {"mine": {"command": "/usr/local/bin/mine", "args": []}}}
      """.data(using: .utf8)

    let merged = try StudioMCPConfigMerger.mergedConfigData(
      userConfigData: userConfig,
      serverPath: config.serverPath,
      environment: config.environment(provider: "claude", sessionId: "s")
    )
    let parsed = try JSONSerialization.jsonObject(with: merged) as? [String: Any]
    let servers = parsed?["mcpServers"] as? [String: Any]
    #expect(servers?.count == 2)
    #expect((servers?["mine"] as? [String: Any])?["command"] as? String == "/usr/local/bin/mine")
    let easel = servers?["easel"] as? [String: Any]
    #expect(easel?["command"] as? String == config.serverPath)
    #expect((easel?["env"] as? [String: String])?["EASEL_SESSION_ID"] == "s")
  }

  @Test("Merger tolerates a missing or unreadable user config")
  func mergerWithoutUserConfig() throws {
    let merged = try StudioMCPConfigMerger.mergedConfigData(
      userConfigData: nil,
      serverPath: config.serverPath,
      environment: [:]
    )
    let parsed = try JSONSerialization.jsonObject(with: merged) as? [String: Any]
    let servers = parsed?["mcpServers"] as? [String: Any]
    #expect(servers?.count == 1)
    #expect(servers?["easel"] != nil)
  }
}
