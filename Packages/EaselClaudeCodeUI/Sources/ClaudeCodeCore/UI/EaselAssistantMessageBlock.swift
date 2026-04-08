import SwiftUI

struct EaselAssistantMessageBlock<Content: View>: View {
  let assistantName: String
  let message: ChatMessage
  @ViewBuilder let content: Content

  @Environment(\.colorScheme) private var colorScheme

  init(
    assistantName: String,
    message: ChatMessage,
    @ViewBuilder content: () -> Content
  ) {
    self.assistantName = assistantName
    self.message = message
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Circle()
          .fill(.primary)
          .frame(width: 5, height: 5)

        Text(assistantName)
          .font(.caption.bold())
          .foregroundStyle(EaselChatRuntimeStyle.secondaryText(for: colorScheme))
      }

      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
