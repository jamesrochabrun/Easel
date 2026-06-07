//
//  DeleteDesignSystemConfirmationView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

/// A destructive, type-the-name-to-approve confirmation for permanently
/// deleting a design system and its local folder.
struct DeleteDesignSystemConfirmationView: View {
  let profile: EaselDesignSystemProfile
  let onCancel: () -> Void
  let onConfirm: () -> Void

  @State private var typedName = ""
  @FocusState private var isFieldFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  private var isConfirmed: Bool {
    typedName.trimmingCharacters(in: .whitespacesAndNewlines) == profile.name
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header
      warning
      confirmField
      actions
    }
    .padding(24)
    .frame(width: 460)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .onAppear { isFieldFocused = true }
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(EaselDesignSystem.Palette.warning)

      VStack(alignment: .leading, spacing: 3) {
        Text("Delete design system")
          .font(.headline)
        Text(profile.name)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 0)
    }
  }

  private var warning: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("This permanently removes the design system's local folder — its catalog, generated page, imported resources, and any sessions created inside it. This action cannot be undone.")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .fixedSize(horizontal: false, vertical: true)

      if !profile.workingDirectory.isEmpty {
        Text(profile.workingDirectory)
          .font(.caption.monospaced())
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            EaselDesignSystem.Palette.canvas(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 6)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 6)
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
      }
    }
  }

  private var confirmField: some View {
    VStack(alignment: .leading, spacing: 7) {
      (Text("Type ") + Text(profile.name).bold() + Text(" to confirm."))
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      TextField("Design system name", text: $typedName)
        .textFieldStyle(.roundedBorder)
        .focused($isFieldFocused)
        .onSubmit {
          if isConfirmed { onConfirm() }
        }
    }
  }

  private var actions: some View {
    HStack(spacing: 10) {
      Spacer()

      Button("Cancel", role: .cancel, action: onCancel)
        .keyboardShortcut(.cancelAction)

      Button("Delete", role: .destructive, action: onConfirm)
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(!isConfirmed)
    }
  }
}
