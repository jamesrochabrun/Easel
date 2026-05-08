//
//  InlineFileSearchManager.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-01-01.
//

import Foundation

// MARK: - InlineFileSearchManager

@MainActor
final class InlineFileSearchManager: InlineFileSearchProtocol {
  
  // MARK: Lifecycle
  
  init(projectPath: String?) {
    self.projectPath = projectPath
  }
  
  // MARK: Internal
  
  func updateSearchPath(_ path: String) {
    projectPath = path
  }
  
  func cancelSearch() {
    cleanup()
  }
  
  func performSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult] {
    try await performMetadataSearch(
      query: query,
      existingFiles: existingFiles,
      maxResults: maxResults,
      mode: .filename
    )
  }
  
  func performContentSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) async throws -> [FileResult] {
    try await performMetadataSearch(
      query: query,
      existingFiles: existingFiles,
      maxResults: maxResults,
      mode: .content
    )
  }
  
  // MARK: Private
  
  private enum SearchMode {
    case filename
    case content
  }

  private var projectPath: String?
  private var metadataQuery: NSMetadataQuery?
  
  private func cleanup() {
    metadataQuery?.stop()
    metadataQuery = nil
  }

  private func performMetadataSearch(
    query: String,
    existingFiles: Set<FileResult>,
    maxResults: Int,
    mode: SearchMode
  ) async throws -> [FileResult] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    cleanup()
    try Task.checkCancellation()

    let queryObject = makeMetadataQuery(query: trimmedQuery, mode: mode)
    let notifications = NotificationCenter.default.notifications(
      named: .NSMetadataQueryDidFinishGathering
    )

    metadataQuery = queryObject
    queryObject.start()
    defer { cleanup() }

    for await notification in notifications {
      try Task.checkCancellation()

      guard let query = notification.object as? NSMetadataQuery else {
        continue
      }
      guard query === queryObject else {
        continue
      }

      query.disableUpdates()
      switch mode {
      case .filename:
        return processQueryResults(
          query,
          existingFiles: existingFiles,
          maxResults: maxResults
        )
      case .content:
        return processQueryResultsWithContent(
          query,
          existingFiles: existingFiles,
          maxResults: maxResults,
          queryString: trimmedQuery
        )
      }
    }

    throw CancellationError()
  }

  private func makeMetadataQuery(
    query trimmedQuery: String,
    mode: SearchMode
  ) -> NSMetadataQuery {
    let queryObject = NSMetadataQuery()
    queryObject.searchScopes = [projectPath as Any].compactMap { $0 }

    let searchPredicate: NSPredicate
    switch mode {
    case .filename:
      searchPredicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemFSNameKey, trimmedQuery)
    case .content:
      searchPredicate = NSPredicate(format: "%K CONTAINS[cd] %@", NSMetadataItemTextContentKey, trimmedQuery)
    }

    let excludeDirectoriesPredicate = NSPredicate(format: "%K != %@", NSMetadataItemContentTypeKey, "public.folder")
    queryObject.predicate = NSCompoundPredicate(
      andPredicateWithSubpredicates: [
        searchPredicate,
        excludeDirectoriesPredicate,
      ]
    )
    queryObject.sortDescriptors = [
      NSSortDescriptor(
        key: NSMetadataItemFSNameKey,
        ascending: true,
        selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
      )
    ]

    return queryObject
  }
  
  private func processQueryResults(
    _ query: NSMetadataQuery,
    existingFiles: Set<FileResult>,
    maxResults: Int
  ) -> [FileResult] {
    var results: [FileResult] = []
    if let items = query.results as? [NSMetadataItem] {
      for item in items.prefix(maxResults) {
        if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
          if let existingFileResult = existingFiles.first(where: { $0.filePath == path }) {
            results.append(existingFileResult)
          } else {
            let fileResult = FileResult(filePath: path, isSelected: false, selectionMode: nil)
            results.append(fileResult)
          }
        }
      }
    }
    return results
  }
  
  private func processQueryResultsWithContent(
    _ query: NSMetadataQuery,
    existingFiles: Set<FileResult>,
    maxResults: Int,
    queryString: String
  ) -> [FileResult] {
    var results = [FileResult]()
    let maxFileSizeInBytes: UInt64 = 5 * 1024 * 1024 // Limit to 5 MB files
    for item in query.results {
      guard let metadataItem = item as? NSMetadataItem else { continue }
      guard let filePath = metadataItem.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
      // Avoid duplicates
      if existingFiles.contains(where: { $0.filePath == filePath }) {
        continue
      }
      // Check file size before reading
      do {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
        if let fileSize = fileAttributes[FileAttributeKey.size] as? UInt64, fileSize <= maxFileSizeInBytes {
          // Read and process the file
          let fileContents = try String(contentsOfFile: filePath, encoding: .utf8)
          let lines = fileContents.components(separatedBy: .newlines)
          let matchingLinesWithNumbers = lines.enumerated().filter { _, line in
            line.lowercased().contains(queryString.lowercased())
          }
          // Create FileLine objects
          let fileLines = matchingLinesWithNumbers.map { index, line in
            FileResult.FileLine(line: line, lineNumber: index + 1)
          }
          // Create FileResult
          let fileResult = FileResult(
            filePath: filePath,
            matchingLines: fileLines
          )
          
          results.append(fileResult)
          if results.count >= maxResults {
            break
          }
        }
      } catch {
        // Handle errors (e.g., file not readable)
        continue
      }
    }
    return results
  }
}
