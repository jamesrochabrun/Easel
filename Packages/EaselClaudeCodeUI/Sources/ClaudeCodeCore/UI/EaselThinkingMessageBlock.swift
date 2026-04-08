import SwiftUI

struct EaselThinkingMessageBlock: View {
  let assistantName: String
  let message: ChatMessage

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    EaselAssistantMessageBlock(assistantName: assistantName, message: message) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Thinking...")
          .font(.callout.italic())
          .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))

        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(message.content)
            .font(.callout.italic())
            .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EaselChatRuntimeStyle.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius))
        }
      }
    }
  }
}
