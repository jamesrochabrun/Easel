import Foundation
import SwiftUI

/// Self-contained management UI for on-device models: curated list with
/// download progress, disk usage, and delete. Embed inside Easel's settings
/// (kept visually neutral so it inherits the host form's styling).
public struct MLXModelManagerView: View {
  @State private var viewModel: MLXModelManagerViewModel

  public init(manager: MLXModelManager) {
    _viewModel = State(initialValue: MLXModelManagerViewModel(manager: manager))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let reason = viewModel.availability.unsupportedReason {
        Label(reason, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .font(.callout)
      } else {
        ForEach(viewModel.rows) { row in
          modelRow(row)
          if row.id != viewModel.rows.last?.id {
            Divider()
          }
        }
      }
    }
    .task {
      await viewModel.refresh()
    }
  }

  @ViewBuilder
  private func modelRow(_ row: MLXModelManagerViewModel.Row) -> some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.model.displayName)
        Text(row.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      switch row.state {
      case .notInstalled:
        Button("Download") {
          viewModel.download(row.model)
        }
        .disabled(!row.fitsHardware)
      case .downloading(let fraction):
        HStack(spacing: 8) {
          ProgressView(value: fraction)
            .frame(width: 90)
          Button("Cancel Download", systemImage: "xmark.circle.fill") {
            viewModel.cancelDownload(row.model)
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
        }
      case .installed(let sizeBytes):
        HStack(spacing: 8) {
          Text(MLXModelManagerViewModel.formatBytes(sizeBytes))
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Delete Model", systemImage: "trash", role: .destructive) {
            viewModel.delete(row.model)
          }
          .labelStyle(.iconOnly)
        }
      case .failed(let message):
        HStack(spacing: 8) {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .font(.caption)
            .lineLimit(1)
          Button("Retry") {
            viewModel.download(row.model)
          }
        }
      }
    }
  }
}

@Observable
@MainActor
final class MLXModelManagerViewModel {
  enum RowState: Equatable {
    case notInstalled
    case downloading(fraction: Double)
    case installed(sizeBytes: Int64)
    case failed(String)
  }

  struct Row: Identifiable {
    let model: MLXCuratedModel
    let state: RowState
    let fitsHardware: Bool

    var id: String { model.id }

    var subtitle: String {
      switch state {
      case .installed:
        return model.notes
      default:
        let size = MLXModelManagerViewModel.formatBytes(model.approximateSizeBytes)
        return fitsHardware ? "\(size) download — \(model.notes)" : "Needs more unified memory than this Mac has."
      }
    }
  }

  let availability = MLXAvailability.check()
  private let manager: MLXModelManager
  private var installed: [String: Int64] = [:]
  private var downloading: [String: Double] = [:]
  private var failures: [String: String] = [:]
  private var downloadTasks: [String: Task<Void, Never>] = [:]

  init(manager: MLXModelManager) {
    self.manager = manager
  }

  var rows: [Row] {
    MLXCuratedModels.all.map { model in
      let state: RowState
      if let fraction = downloading[model.id] {
        state = .downloading(fraction: fraction)
      } else if let size = installed[model.id] {
        state = .installed(sizeBytes: size)
      } else if let failure = failures[model.id] {
        state = .failed(failure)
      } else {
        state = .notInstalled
      }
      return Row(
        model: model,
        state: state,
        fitsHardware: model.minimumTier <= availability.recommendedMaxTier
      )
    }
  }

  func refresh() async {
    let models = await manager.installedModels()
    installed = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0.sizeBytes) })
  }

  func download(_ model: MLXCuratedModel) {
    guard downloadTasks[model.id] == nil else { return }
    failures[model.id] = nil
    downloading[model.id] = 0
    let task = Task {
      do {
        try await manager.download(repoId: model.id) { [weak self] fraction in
          Task { @MainActor [weak self] in
            self?.downloading[model.id] = fraction
          }
        }
        await refresh()
      } catch is CancellationError {
        // Cancelled by the user; nothing to report.
      } catch {
        failures[model.id] = error.localizedDescription
      }
      downloading[model.id] = nil
      downloadTasks[model.id] = nil
    }
    downloadTasks[model.id] = task
  }

  func cancelDownload(_ model: MLXCuratedModel) {
    downloadTasks[model.id]?.cancel()
  }

  func delete(_ model: MLXCuratedModel) {
    Task {
      try? await manager.delete(repoId: model.id)
      await refresh()
    }
  }

  nonisolated static func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}
