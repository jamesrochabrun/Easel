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

  func testFilenameFromLabelLineAboveFence() {
    // The real MLX failure: model labels blocks with a header line, not an
    // info-string filename.
    let text = """
    Here's the page:

    index.html
    ```html
    <!doctype html><html><head><link rel="stylesheet" href="styles.css"><script src="script.js"></script></head><body></body></html>
    ```

    **styles.css**
    ```css
    body { font-family: sans-serif; }
    ```

    script.js
    ```javascript
    console.log("ready")
    ```
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(Set(files.map(\.relativePath)), ["index.html", "styles.css", "script.js"])
    XCTAssertTrue(CodeFileExtractor.containsEntryPoint(files))
    XCTAssertTrue(files.first { $0.relativePath == "styles.css" }!.content.contains("sans-serif"))
    XCTAssertTrue(files.first { $0.relativePath == "script.js" }!.content.contains("ready"))
  }

  func testFilenameHeaderSeparatedFromFenceByProse() {
    // The real MLX "Step N: Create `file`" pattern: the filename header is a
    // line or two above the fence, with a description sentence in between.
    let text = """
    ### Step 1: Create `index.html`
    Here is the page structure.
    ```html
    <!doctype html><html><head><link rel="stylesheet" href="styles.css"><script src="script.js"></script></head><body></body></html>
    ```

    ### Step 2: Create `styles.css`
    Let's add some styling for the layout.
    ```css
    body { font-family: sans-serif; }
    ```

    ### Step 3: Create `script.js`
    Let's add some basic JavaScript to handle the button click event.
    ```javascript
    document.querySelector('.cta').addEventListener('click', () => alert('hi'))
    ```
    """
    let files = CodeFileExtractor.extractFiles(from: text)
    XCTAssertEqual(Set(files.map(\.relativePath)), ["index.html", "styles.css", "script.js"])
    XCTAssertTrue(files.first { $0.relativePath == "styles.css" }!.content.contains("sans-serif"))
    XCTAssertTrue(files.first { $0.relativePath == "script.js" }!.content.contains("addEventListener"))
  }

  func testBacktickFilenameExtraction() {
    XCTAssertEqual(CodeFileExtractor.filenameInBackticks("### Step 3: Create `script.js`"), "script.js")
    XCTAssertEqual(CodeFileExtractor.filenameInBackticks("Now edit `styles.css` to add colors"), "styles.css")
    XCTAssertNil(CodeFileExtractor.filenameInBackticks("Use `flexbox` for centering"))
    XCTAssertNil(CodeFileExtractor.filenameInBackticks("no backticks here at all"))
  }

  func testLabelVariants() {
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "script.js"), "script.js")
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "**styles.css**"), "styles.css")
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "`app.js`"), "app.js")
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "styles.css:"), "styles.css")
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "### script.js"), "script.js")
    XCTAssertEqual(CodeFileExtractor.filename(fromLabel: "File: styles.css"), "styles.css")
    // A full sentence that merely mentions a file must be ignored.
    XCTAssertNil(CodeFileExtractor.filename(fromLabel: "This is a basic structure for the landing page."))
    XCTAssertNil(CodeFileExtractor.filename(fromLabel: "The HTML links to styles.css for the layout and colors."))
  }

  func testSentenceLabelDoesNotMislabelSnippet() {
    // A CSS snippet under an explanatory sentence must not become a file.
    let text = """
    To center the box you can use flexbox like this:
    ```css
    .box { display: flex; }
    ```
    """
    XCTAssertFalse(CodeFileExtractor.containsEntryPoint(CodeFileExtractor.extractFiles(from: text)))
  }

  func testRejectsUnsafeFilenames() {
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "css ../../etc/passwd"))
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "css /abs/path.css"))
    XCTAssertNil(CodeFileExtractor.filename(fromInfoString: "python script.py"))
    XCTAssertEqual(CodeFileExtractor.filename(fromInfoString: "css styles.css"), "styles.css")
    XCTAssertEqual(CodeFileExtractor.filename(fromInfoString: "html:pages/about.html"), "pages/about.html")
  }
}
