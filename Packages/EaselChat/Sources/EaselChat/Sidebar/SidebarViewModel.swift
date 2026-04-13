//
//  SidebarViewModel.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

@Observable @MainActor
public final class SidebarViewModel {

  // MARK: - Public State

  private(set) var projectGroups: [ProjectGroup] = []
  public var selectedSessionId: String?
  public var isSidebarVisible: Bool = true

  // MARK: - Callbacks

  public var onSessionSelected: ((StoredSession) -> Void)?
  public var onNewChatRequested: ((String?) -> Void)?
  public var onDeleteSession: ((StoredSession) -> Void)?

  // MARK: - Private

  private let sessionStorage: SessionStorageProtocol
  private var addedProjectDirectories: [String]

  private static let projectDirectoriesKey = "easel.addedProjectDirectories"

  // MARK: - Init

  public init(sessionStorage: SessionStorageProtocol) {
    self.sessionStorage = sessionStorage
    self.addedProjectDirectories = UserDefaults.standard.stringArray(forKey: Self.projectDirectoriesKey) ?? []
  }

  // MARK: - Public Methods

  public func loadSessions() async {
    do {
      let sessions = try await sessionStorage.getAllSessions()
      let dbGroups = ProjectGroup.groupByProject(sessions)

      // Build final list following addedProjectDirectories order
      var result: [ProjectGroup] = []
      var usedDirs = Set<String>()

      for dir in addedProjectDirectories {
        if let existing = dbGroups.first(where: { $0.id == dir }) {
          result.append(existing)
        } else {
          let displayName = URL(fileURLWithPath: dir).lastPathComponent
          result.append(ProjectGroup(
            id: dir,
            displayName: displayName,
            workingDirectory: dir,
            sessions: [],
            isExpanded: true
          ))
        }
        usedDirs.insert(dir)
      }

      // Append any DB groups not in addedProjectDirectories (e.g., from other sources)
      for group in dbGroups where !usedDirs.contains(group.id) {
        result.append(group)
      }

      // Preserve expansion state from previous load
      let previousExpansion = Dictionary(uniqueKeysWithValues: projectGroups.map { ($0.id, $0.isExpanded) })
      for i in result.indices {
        if let wasExpanded = previousExpansion[result[i].id] {
          result[i].isExpanded = wasExpanded
        }
      }

      projectGroups = result
    } catch {
      projectGroups = []
    }
  }

  func toggleProject(_ projectId: String) {
    guard let index = projectGroups.firstIndex(where: { $0.id == projectId }) else { return }
    projectGroups[index].isExpanded.toggle()
  }

  public func toggleSidebar() {
    isSidebarVisible.toggle()
  }

  func selectSession(_ session: StoredSession) {
    selectedSessionId = session.id
    onSessionSelected?(session)
  }

  func requestNewChat(workingDirectory: String?) {
    if let dir = workingDirectory, !addedProjectDirectories.contains(dir) {
      addedProjectDirectories.append(dir)
      persistProjectDirectories()
    }
    selectedSessionId = nil
    onNewChatRequested?(workingDirectory)
  }

  func deleteSession(_ session: StoredSession) {
    onDeleteSession?(session)
  }

  // MARK: - Private

  private func persistProjectDirectories() {
    UserDefaults.standard.set(Array(addedProjectDirectories), forKey: Self.projectDirectoriesKey)
  }
}
