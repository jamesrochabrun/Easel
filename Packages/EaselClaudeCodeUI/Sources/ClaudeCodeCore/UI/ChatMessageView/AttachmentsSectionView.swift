import AppKit
import EaselKit
import SwiftUI

struct AttachmentsSectionView: View {
  let attachments: [StoredAttachment]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(attachments) { attachment in
          StoredAttachmentView(attachment: attachment)
        }
      }
      .padding(.horizontal, 12)
    }
  }
}

/// One attachment tile in a sent message. Images render a real thumbnail
/// re-read from the stored file path (attachments are copied into the
/// app-owned store at drop time, so the path stays alive across sessions);
/// everything else keeps the icon card. Tapping an image opens a preview.
struct StoredAttachmentView: View {
  let attachment: StoredAttachment
  @Environment(\.colorScheme) private var colorScheme
  @State private var thumbnail: NSImage?
  @State private var isShowingPreview = false

  var body: some View {
    Group {
      if let thumbnail {
        Image(nsImage: thumbnail)
          .resizable()
          .scaledToFill()
          .frame(width: 80, height: 80)
          .contentShape(Rectangle())
          .onTapGesture {
            isShowingPreview = true
          }
          .help(attachment.fileName)
      } else {
        iconCard
      }
    }
    .frame(width: 80, height: 80)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .task(id: attachment.filePath) {
      await loadThumbnailIfNeeded()
    }
    .sheet(isPresented: $isShowingPreview) {
      StoredAttachmentPreviewView(attachment: attachment)
    }
  }

  private var iconCard: some View {
    VStack(spacing: 4) {
      Image(systemName: iconName)
        .font(.system(size: 24))
        .foregroundColor(EaselDesignSystem.Palette.accent)

      Text(attachment.fileName)
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .frame(width: 80, height: 80)
  }

  private var iconName: String {
    switch attachment.type {
    case "image": return "photo"
    case "pdf": return "doc.richtext"
    case "text": return "doc.text"
    case "code": return "chevron.left.forwardslash.chevron.right"
    case "json": return "curlybraces"
    default: return "doc"
    }
  }

  private func loadThumbnailIfNeeded() async {
    guard attachment.type == "image", thumbnail == nil else { return }
    let path = attachment.filePath
    let loaded = await Task.detached(priority: .utility) { () -> NSImage? in
      StoredAttachmentImageLoader.thumbnail(atPath: path, maxDimension: 160)
    }.value
    thumbnail = loaded
  }
}

/// Full-size preview sheet for an image attachment in the feed.
private struct StoredAttachmentPreviewView: View {
  let attachment: StoredAttachment
  @Environment(\.dismiss) private var dismiss
  @State private var image: NSImage?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(attachment.fileName)
          .font(.headline)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.cancelAction)
      }
      .padding(12)

      Divider()

      Group {
        if let image {
          Image(nsImage: image)
            .resizable()
            .scaledToFit()
        } else {
          VStack(spacing: 8) {
            Image(systemName: "photo")
              .font(.system(size: 32))
              .foregroundStyle(.secondary)
            Text("The image file is no longer available.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(12)
    }
    .frame(minWidth: 480, minHeight: 360)
    .task {
      let path = attachment.filePath
      image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
        NSImage(contentsOfFile: path)
      }.value
    }
  }
}

/// Loads and downscales an image off the main thread for feed thumbnails.
enum StoredAttachmentImageLoader {
  static func thumbnail(atPath path: String, maxDimension: CGFloat) -> NSImage? {
    guard let image = NSImage(contentsOfFile: path) else { return nil }

    let size = image.size
    guard size.width > 0, size.height > 0 else { return nil }

    let scale = min(1, maxDimension / max(size.width, size.height))
    guard scale < 1 else { return image }

    let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
    let resized = NSImage(size: targetSize)
    resized.lockFocus()
    image.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: NSRect(origin: .zero, size: size),
      operation: .copy,
      fraction: 1
    )
    resized.unlockFocus()
    return resized
  }
}
