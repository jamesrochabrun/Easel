import SwiftUI

struct EaselUserMessageBubble: View {
  let message: ChatMessage
  let fontSize: Double

  @Environment(\.colorScheme) private var colorScheme
  private let relativeFormatter = RelativeMessageTimeFormatter()

  var body: some View {
    HStack {
      Spacer(minLength: 48)

      VStack(alignment: .trailing, spacing: 5) {
        EaselMarkdownMessageView(
          content: message.content,
          role: message.role,
          fontSize: CGFloat(fontSize),
          isComplete: message.isComplete,
          fillsAvailableWidth: false
        )
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(
            EaselChatRuntimeStyle.userMessageBubble(for: colorScheme),
            in: RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.cardRadius)
          )

        Text(relativeFormatter.string(from: message.timestamp))
          .font(.caption)
          .foregroundStyle(EaselChatRuntimeStyle.tertiaryText(for: colorScheme))
      }
      .frame(maxWidth: 300, alignment: .trailing)
    }
  }
}
