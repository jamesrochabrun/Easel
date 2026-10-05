import ArgumentParser
import Foundation

@main
struct EaselMCPCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "easel-mcp",
    abstract: "Easel command-line helper.",
    subcommands: [
      EaselMCPServerCommand.self,
    ],
    defaultSubcommand: EaselMCPServerCommand.self
  )
}

struct EaselMCPServerCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mcp-server",
    abstract: "Run the Easel MCP server over stdio."
  )

  func run() async throws {
    try await EaselMCPServer().run()
  }
}
