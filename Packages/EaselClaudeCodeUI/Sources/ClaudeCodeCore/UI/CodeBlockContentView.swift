import EaselKit
import SwiftUI

struct CodeBlockContentView: View {
  
  @Bindable var code: CodeBlockElement
  let role: MessageRole
  let showArtifact: ((Artifact) -> Void)?
  let iconSizes: CGFloat = 15
  
  @Environment(\.colorScheme) private var colorScheme
  
  init(code: CodeBlockElement, role: MessageRole, showArtifact: ((Artifact) -> Void)? = nil) {
    self.code = code
    self.role = role
    self.showArtifact = showArtifact
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        // File icon and path
        if let filePath = code.filePath {
          Image(systemName: fileIcon(for: filePath))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          
          Text(URL(fileURLWithPath: filePath).lastPathComponent)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        } else if let language = code.language {
          Text(language)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        // View Diagram button for mermaid
        if let showArtifact = showArtifact,
           let language = code.language,
           language.lowercased() == "mermaid",
           let content = code.copyableContent {
          Button(action: {
            showArtifact(.diagram(content))
          }) {
            HStack(spacing: 4) {
              Image(systemName: "flowchart")
                .font(.system(size: 12))
              Text("View")
                .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(EaselDesignSystem.Palette.accent.opacity(0.10))
            .foregroundColor(EaselDesignSystem.Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
          }
          .buttonStyle(.plain)
          .help("View Mermaid Diagram")
        }
        
        // Copy button with feedback
        if let copyableContent = code.copyableContent {
          CopyButton(
            textToCopy: copyableContent,
            iconSize: iconSizes
          )
        }
        
        // Loading indicator for incomplete code blocks
        if !code.isComplete {
          ProgressView()
            .controlSize(.small)
            .frame(width: iconSizes, height: iconSizes)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(headerBackground)
      
      Divider()
      
      // Code content
      ScrollView(.vertical) {
        ScrollView(.horizontal, showsIndicators: false) {
          Text(code.content)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(codeTextColor)
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxHeight: 500)
      .background(codeBackground)
    }
    .clipShape(RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius))
    .overlay(
      RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius)
        .strokeBorder(borderColor, lineWidth: 1)
    )
  }
  
  private var headerBackground: Color {
    EaselChatRuntimeStyle.cardBackground(for: colorScheme)
  }
  
  private var codeBackground: Color {
    EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme)
  }
  
  private var borderColor: Color {
    EaselChatRuntimeStyle.border(for: colorScheme)
  }
  
  private var codeTextColor: Color {
    EaselChatRuntimeStyle.secondaryText(for: colorScheme)
  }
  
  private func fileIcon(for path: String) -> String {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    
    switch ext {
    case "swift":
      return "swift"
    case "js", "jsx", "ts", "tsx":
      return "curlybraces"
    case "py":
      return "chevron.left.forwardslash.chevron.right"
    case "json", "xml", "yml", "yaml":
      return "doc.text"
    case "md", "markdown":
      return "text.alignleft"
    case "sh", "bash":
      return "terminal"
    default:
      return "doc"
    }
  }
  
}
