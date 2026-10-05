import Foundation
import Testing

@testable import EaselMCPServer

@Suite("EaselMCPServer")
struct EaselMCPServerTests {
  @Test("Every Studio tool carries MCP annotations and list/get are read-only")
  func annotationsCoverEveryTool() {
    let names = ["easel_artifact", "easel_design", "easel_list_artifacts", "easel_get_artifact"]
    for name in names {
      let annotations = EaselMCPServer.toolAnnotationsByName[name]
      #expect(annotations != nil, "\(name) has no annotations")
      #expect(annotations?["openWorldHint"] as? Bool == false)
    }
    #expect(EaselMCPServer.toolAnnotationsByName["easel_list_artifacts"]?["readOnlyHint"] as? Bool == true)
    #expect(EaselMCPServer.toolAnnotationsByName["easel_get_artifact"]?["readOnlyHint"] as? Bool == true)
    #expect(EaselMCPServer.toolAnnotationsByName["easel_design"]?["readOnlyHint"] as? Bool == false)
  }

  @Test("annotated() attaches annotations by name and passes unknown schemas through")
  func annotatedAttaches() {
    let schema: [String: Any] = ["name": "easel_design"]
    let annotated = EaselMCPServer.annotated(schema)
    #expect(annotated["annotations"] != nil)

    let unknown: [String: Any] = ["name": "not_a_tool"]
    #expect(EaselMCPServer.annotated(unknown)["annotations"] == nil)
  }
}
