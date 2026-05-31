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

// Simple view for stored attachments
struct StoredAttachmentView: View {
  let attachment: StoredAttachment
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
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
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
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
}
