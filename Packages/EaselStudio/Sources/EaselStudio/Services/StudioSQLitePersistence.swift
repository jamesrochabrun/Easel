import EaselStudioCore
import Foundation
import SQLite

/// SQLite-backed `StudioPersisting` in a dedicated `studio.sqlite`.
///
/// Deliberately its own database rather than a table in ClaudeCodeCore's
/// sessions store: artifacts are keyed by project, not session, and a separate
/// file keeps EaselStudio free of a dependency on the chat engine's schema.
/// `id` is the primary key with upsert-on-conflict so a re-file (or a
/// double-drained queue record) refreshes the row in place.
public actor StudioSQLitePersistence: StudioPersisting {
  public static let currentSchemaVersion: Int32 = 1

  private let databaseURL: URL
  private var connection: Connection?

  private let table = Table(StudioArtifactRecord.databaseTableName)
  private let idColumn = SQLite.Expression<String>("id")
  private let projectPathColumn = SQLite.Expression<String>("projectPath")
  private let sessionIdColumn = SQLite.Expression<String>("sessionId")
  private let providerColumn = SQLite.Expression<String>("provider")
  private let kindColumn = SQLite.Expression<String>("kind")
  private let createdAtColumn = SQLite.Expression<Date>("createdAt")
  private let updatedAtColumn = SQLite.Expression<Date>("updatedAt")
  private let payloadVersionColumn = SQLite.Expression<Int>("payloadVersion")
  private let payloadDataColumn = SQLite.Expression<Blob>("payloadData")

  public static func defaultDatabaseURL(fileManager: FileManager = .default) -> URL {
    StudioSupportDirectory.baseURL(fileManager: fileManager)
      .appendingPathComponent("studio.sqlite", isDirectory: false)
  }

  public init(databaseURL: URL = StudioSQLitePersistence.defaultDatabaseURL()) {
    self.databaseURL = databaseURL
  }

  // MARK: - StudioPersisting

  public func saveStudioArtifact(_ record: StudioArtifactRecord) async throws {
    let db = try database()
    try db.run(table.insert(
      or: .replace,
      idColumn <- record.id,
      projectPathColumn <- record.projectPath,
      sessionIdColumn <- record.sessionId,
      providerColumn <- record.provider,
      kindColumn <- record.kind,
      createdAtColumn <- record.createdAt,
      updatedAtColumn <- record.updatedAt,
      payloadVersionColumn <- record.payloadVersion,
      payloadDataColumn <- Blob(bytes: [UInt8](record.payloadData))
    ))
  }

  public func getStudioArtifacts(forProjectPath projectPath: String) async throws -> [StudioArtifactRecord] {
    let db = try database()
    return try db.prepare(table.filter(projectPathColumn == projectPath)).map(makeRecord(from:))
  }

  public func getAllStudioArtifacts() async throws -> [StudioArtifactRecord] {
    let db = try database()
    return try db.prepare(table).map(makeRecord(from:))
  }

  public func deleteStudioArtifact(id: String) async throws {
    let db = try database()
    try db.run(table.filter(idColumn == id).delete())
  }

  public func deleteAllStudioArtifacts(forProjectPath projectPath: String) async throws {
    let db = try database()
    try db.run(table.filter(projectPathColumn == projectPath).delete())
  }

  // MARK: - Schema

  private func database() throws -> Connection {
    if let connection { return connection }

    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let db = try Connection(databaseURL.path)
    try migrate(db)
    connection = db
    return db
  }

  private func migrate(_ db: Connection) throws {
    try db.run(table.create(ifNotExists: true) { builder in
      builder.column(idColumn, primaryKey: true)
      builder.column(projectPathColumn)
      builder.column(sessionIdColumn)
      builder.column(providerColumn)
      builder.column(kindColumn)
      builder.column(createdAtColumn)
      builder.column(updatedAtColumn)
      builder.column(payloadVersionColumn)
      builder.column(payloadDataColumn)
    })
    try db.run(table.createIndex(projectPathColumn, ifNotExists: true))
    if db.userVersion ?? 0 < Self.currentSchemaVersion {
      db.userVersion = Self.currentSchemaVersion
    }
  }

  private func makeRecord(from row: Row) throws -> StudioArtifactRecord {
    StudioArtifactRecord(
      id: row[idColumn],
      projectPath: row[projectPathColumn],
      sessionId: row[sessionIdColumn],
      provider: row[providerColumn],
      kind: row[kindColumn],
      createdAt: row[createdAtColumn],
      updatedAt: row[updatedAtColumn],
      payloadVersion: row[payloadVersionColumn],
      payloadData: Data(row[payloadDataColumn].bytes)
    )
  }
}
