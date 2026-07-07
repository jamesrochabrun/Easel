import XCTest
@testable import AgentHarness

final class CodeFileExtractorTests: XCTestCase {

  func testCompleteHTMLDocumentBecomesIndexHTML() {
    let text = """
    Sure, here is the landing page:
    ```html
    <!DOCTYPE html>
    <html><head><title>Peru</title></head><body><h1>Lima</h1></body></html>
    ```
    Let me know if you want changes.
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(files.count, 1)
    XCTAssertEqual(files[0].relativePath, "index.html")
    XCTAssertTrue(files[0].content.contains("<h1>Lima</h1>"))
    XCTAssertTrue(CodeFileExtractor.containsEntryPoint(files))
  }

  func testHTMLDocumentDetectedWithoutDoctype() {
    let text = "```\n<html>\n<body>hi</body>\n</html>\n```"
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(files.map(\.relativePath), ["index.html"])
  }

  func testNamedFilesAlongsideHTML() {
    let text = """
    ```html
    <!doctype html><html><head><link rel="stylesheet" href="styles.css"></head><body></body></html>
    ```
    ```css styles.css
    body { color: red; }
    ```
    ```javascript app.js
    console.log("hi")
    ```
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(Set(files.map(\.relativePath)), ["index.html", "styles.css", "app.js"])
    XCTAssertTrue(CodeFileExtractor.containsEntryPoint(files))
  }

  func testExplanatorySnippetWithoutHTMLDocIsNotAnEntryPoint() {
    // A CSS snippet in an explanation — no complete document → host won't apply.
    let text = """
    To center it, use flexbox:
    ```css
    .box { display: flex; justify-content: center; }
    ```
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertFalse(CodeFileExtractor.containsEntryPoint(files), "no full document means no auto-apply")
  }

  func testPlainProseYieldsNothing() {
    XCTAssertTrue(CodeFileExtractor.extractFiles(from: "I changed the header color to blue.").isEmpty)
  }

  func testUnterminatedFenceIsIgnored() {
    let text = "```html\n<!doctype html><html></html>"
    XCTAssertTrue(CodeFileExtractor.extractFiles(from: text).isEmpty, "no closing fence → skip")
  }

  func testLastBlockForAPathWins() {
    let text = """
    ```html
    <!doctype html><html><body>v1</body></html>
    ```
    On second thought:
    ```html
    <!doctype html><html><body>v2</body></html>
    ```
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(files.count, 1)
    XCTAssertTrue(files[0].content.contains("v2"))
    XCTAssertFalse(files[0].content.contains("v1"))
  }

  func testRejectsUnsafeFilenames() {
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "css ../../etc/passwd"))
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "css /abs/path.css"))
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "python script.py"))
    XCTAssertEqual(CodeFileExtractor.filename(fromInfoString: "css styles.css"), "styles.css")
    XCTAssertEqual(CodeFileExtractor.filename(fromInfoString: "html:pages/about.html"), "pages/about.html")
  }
}
