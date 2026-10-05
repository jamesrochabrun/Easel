import Darwin
import EaselStudioCore
import Foundation

/// The MCP server Easel attaches to Claude and Codex sessions.
///
/// Speaks JSON-RPC over stdio and exposes the Studio tools: file a document
/// or a canvas of design variants into Easel's Designs surface, list what is
/// already filed, and fetch an artifact's current payload (including edits
/// the user made in the canvas). Tools only validate and enqueue — this
/// process never shares memory with the app; the app drains the queue.
///
/// Provenance comes from the environment Easel bakes into the server entry:
/// `EASEL_PROVIDER` (required), `EASEL_PROJECT_PATH` (required for routing),
/// `EASEL_SESSION_ID` (optional — Easel spawns a fresh CLI process per turn,
/// so the first turn has no session id yet), `EASEL_APP_SUPPORT_DIR`
/// (so app and server agree on one directory).
struct EaselMCPServer {
  private let studioQueue = StudioArtifactQueue()
  private let studioIndex = StudioIndexStore()

  func run() async throws {
    while let line = readLine(strippingNewline: true) {
      guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
      handleLine(line)
    }
  }

  private func handleLine(_ line: String) {
    guard let data = line.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let method = object["method"] as? String
    else {
      return
    }

    let id = object["id"]
    switch method {
    case "initialize":
      guard let id else { return }
      let protocolVersion = ((object["params"] as? [String: Any])?["protocolVersion"] as? String)
        ?? "2024-11-05"
      writeResponse(id: id, result: [
        "protocolVersion": protocolVersion,
        "capabilities": [
          "tools": [:],
        ],
        "serverInfo": [
          "name": "easel",
          "version": "1.0.0",
        ],
      ])

    case "tools/list":
      guard let id else { return }
      let schemas: [[String: Any]] = [
        artifactToolSchema(),
        designToolSchema(),
        listArtifactsToolSchema(),
        getArtifactToolSchema(),
      ]
      writeResponse(id: id, result: [
        "tools": schemas.map(Self.annotated),
      ])

    case "tools/call":
      guard let id else { return }
      do {
        let result = try handleToolCall(params: object["params"] as? [String: Any])
        writeResponse(id: id, result: result)
      } catch {
        writeError(id: id, code: -32000, message: error.localizedDescription)
      }

    default:
      guard let id else { return }
      writeError(id: id, code: -32601, message: "Method not found: \(method)")
    }
  }

  private func handleToolCall(params: [String: Any]?) throws -> [String: Any] {
    guard let params,
          let name = params["name"] as? String
    else {
      throw MCPError.invalidRequest("Missing tool name.")
    }
    let arguments = params["arguments"] as? [String: Any] ?? [:]

    switch name {
    case "easel_artifact":
      return try fileArtifact(arguments: arguments)

    case "easel_design":
      return try fileDesign(arguments: arguments)

    case "easel_list_artifacts":
      return listStudioArtifacts(arguments: arguments)

    case "easel_get_artifact":
      return try getStudioArtifact(arguments: arguments)

    default:
      throw MCPError.invalidRequest("Unknown Easel tool: \(name).")
    }
  }

  // MARK: - Studio

  /// Files one HTML document into the project's Designs surface.
  ///
  /// The document is served verbatim from Easel's own directory — it never
  /// touches the project. An explicit id re-files an existing artifact in place.
  private func fileArtifact(arguments: [String: Any]) throws -> [String: Any] {
    let provider = try studioProvider(toolName: "easel_artifact")
    let title = try studioTitle("title", in: arguments)
    let html = try requiredString("html", in: arguments)

    let byteCount = html.utf8.count
    guard byteCount <= StudioArtifact.Limits.maxDocumentBytes else {
      throw MCPError.invalidRequest(
        "easel_artifact html is \(byteCount) bytes but the limit is \(StudioArtifact.Limits.maxDocumentBytes). Trim embedded assets or split the document."
      )
    }

    let artifact = StudioArtifact(
      id: studioIdentifier(in: arguments),
      kind: .document,
      title: title,
      html: html,
      sourceProvider: provider,
      sourceSessionId: ProcessInfo.processInfo.environment["EASEL_SESSION_ID"],
      sourceProjectPath: ProcessInfo.processInfo.environment["EASEL_PROJECT_PATH"],
      sourceProcessId: getppid()
    )
    try studioQueue.enqueue(artifact)

    return toolResult(
      text: "Easel is rendering \"\(title)\". It appears in the Designs surface of the canvas pane momentarily. Re-file with id \(artifact.id) to update it in place.",
      structuredContent: [
        "queued": true,
        "id": artifact.id,
        "kind": StudioArtifactKind.document.rawValue,
        "title": title,
      ]
    )
  }

  /// Files N variants of one component onto a design canvas.
  ///
  /// Every variant is normalized to a fragment and its CSS is checked to scope
  /// cleanly *here*, at the tool boundary: CSS that cannot be isolated to one
  /// artboard is a correctable error for the agent, never a canvas that quietly
  /// restyles its neighbours.
  private func fileDesign(arguments: [String: Any]) throws -> [String: Any] {
    let provider = try studioProvider(toolName: "easel_design")
    let component = try studioTitle("component", in: arguments)

    guard let rawVariants = arguments["variants"] as? [[String: Any]], !rawVariants.isEmpty else {
      throw MCPError.invalidRequest(
        "easel_design needs variants: a non-empty array of { name, html, css?, notes?, width?, height? } objects."
      )
    }
    guard rawVariants.count <= StudioArtifact.Limits.maxVariants else {
      throw MCPError.invalidRequest(
        "easel_design has \(rawVariants.count) variants but the limit is \(StudioArtifact.Limits.maxVariants). A canvas is a comparison, not a gallery — pick the ones worth comparing."
      )
    }

    var variants: [StudioVariant] = []
    var warnings: [String] = []
    var seenNames: Set<String> = []
    for (index, raw) in rawVariants.enumerated() {
      guard let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
      else {
        throw MCPError.invalidRequest("Variant \(index + 1) needs a non-empty name.")
      }
      guard name.count <= StudioArtifact.Limits.maxNameLength else {
        throw MCPError.invalidRequest(
          "Variant name \"\(name.prefix(20))…\" is longer than \(StudioArtifact.Limits.maxNameLength) characters."
        )
      }
      guard seenNames.insert(name.lowercased()).inserted else {
        throw MCPError.invalidRequest("Variant names must be unique; \"\(name)\" appears more than once.")
      }
      guard let rawHTML = raw["html"] as? String,
            !rawHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw MCPError.invalidRequest("Variant \"\(name)\" needs non-empty html.")
      }

      let normalized = StudioFragmentNormalizer.normalize(rawHTML)
      warnings.append(contentsOf: normalized.warnings.map { "\(name): \($0)" })

      let extraCSS = (raw["css"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let css = [normalized.css, extraCSS].filter { !$0.isEmpty }.joined(separator: "\n\n")

      let byteCount = normalized.html.utf8.count + css.utf8.count
      guard byteCount <= StudioArtifact.Limits.maxVariantBytes else {
        throw MCPError.invalidRequest(
          "Variant \"\(name)\" is \(byteCount) bytes but the limit is \(StudioArtifact.Limits.maxVariantBytes) per variant."
        )
      }

      do {
        let scoped = try StudioCSSScoper.scope(css, variantName: name)
        warnings.append(contentsOf: scoped.warnings.map { "\(name): \($0)" })
      } catch let error as StudioCSSScoper.ParseError {
        throw MCPError.invalidRequest(
          "Variant \"\(name)\" CSS did not parse — \(error.reason.lowercased()) at character \(error.offset). Fix the CSS and re-file."
        )
      }

      let notes = (raw["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let notes, notes.count > StudioArtifact.Limits.maxNotesLength {
        throw MCPError.invalidRequest(
          "Variant \"\(name)\" notes are longer than \(StudioArtifact.Limits.maxNotesLength) characters."
        )
      }

      variants.append(StudioVariant(
        name: name,
        html: normalized.html,
        css: css,
        notes: notes.flatMap { $0.isEmpty ? nil : $0 },
        width: studioDimension(raw["width"], label: "width", variant: name),
        height: studioDimension(raw["height"], label: "height", variant: name)
      ))
    }

    let props: [StudioTweakProp]
    do {
      props = try StudioTweakPropParser.parse(arguments["props"])
    } catch let error as StudioTweakPropParser.ValidationError {
      throw MCPError.invalidRequest("easel_design props: \(error.message)")
    }
    let unused = StudioTweakPropParser.unusedProps(props, variants: variants)
    guard unused.isEmpty else {
      throw MCPError.invalidRequest(
        "easel_design props \(unused.map { "\"\($0)\"" }.joined(separator: ", ")) are declared but no variant uses them, so the Tweaks panel would move nothing. Reference each prop from variant CSS as var(--\(unused[0])) (or mark an element data-prop=\"\(unused[0])\" for text/select), or drop the prop."
      )
    }

    let artifact = StudioArtifact(
      id: studioIdentifier(in: arguments),
      kind: .canvas,
      title: component,
      sourcePath: optionalString("sourcePath", in: arguments).flatMap { $0.isEmpty ? nil : $0 },
      variants: variants,
      props: props,
      warnings: warnings,
      sourceProvider: provider,
      sourceSessionId: ProcessInfo.processInfo.environment["EASEL_SESSION_ID"],
      sourceProjectPath: ProcessInfo.processInfo.environment["EASEL_PROJECT_PATH"],
      sourceProcessId: getppid()
    )
    try studioQueue.enqueue(artifact)

    var text = "Easel is laying out \(variants.count) variant(s) of \"\(component)\" on the design canvas. It appears in the Designs surface momentarily. Re-file with id \(artifact.id) to update the canvas in place."
    if !props.isEmpty {
      text += " \(props.count) tweakable prop(s) are exposed to every variant as CSS custom properties: " + props.map { "var(\($0.cssVariableName))" }.joined(separator: ", ") + "."
    }
    if !warnings.isEmpty {
      text += "\n\nWarnings:\n" + warnings.map { "• \($0)" }.joined(separator: "\n")
    }

    return toolResult(
      text: text,
      structuredContent: [
        "queued": true,
        "id": artifact.id,
        "kind": StudioArtifactKind.canvas.rawValue,
        "component": component,
        "variants": variants.map(\.name),
        "props": props.map(\.name),
        "warnings": warnings,
      ]
    )
  }

  /// Lists the Studio artifacts already filed for this project.
  ///
  /// Without this an agent asked to "make the ghost button bolder" has no way
  /// to learn the canvas's id, so it files a second canvas beside the first
  /// instead of refining the one the user is looking at.
  private func listStudioArtifacts(arguments: [String: Any]) -> [String: Any] {
    let projectPath = optionalString("projectPath", in: arguments)
      ?? ProcessInfo.processInfo.environment["EASEL_PROJECT_PATH"]
      ?? FileManager.default.currentDirectoryPath

    guard let index = studioIndex.read(projectPath: projectPath), !index.artifacts.isEmpty else {
      return toolResult(
        text: "No Studio artifacts filed for this project yet.",
        structuredContent: ["projectPath": projectPath, "artifacts": []]
      )
    }

    let formatter = ISO8601DateFormatter()
    let entries = index.artifacts.map { entry -> [String: Any] in
      var object: [String: Any] = [
        "id": entry.id,
        "kind": entry.kind.rawValue,
        "title": entry.title,
        "revision": entry.revision,
        "updatedAt": formatter.string(from: entry.updatedAt),
      ]
      if !entry.variantNames.isEmpty { object["variants"] = entry.variantNames }
      if let sourcePath = entry.sourcePath { object["sourcePath"] = sourcePath }
      if let documentPath = entry.documentPath { object["documentPath"] = documentPath }
      return object
    }

    let summary = index.artifacts
      .map { entry in
        let detail = entry.kind == .canvas
          ? "canvas: \(entry.variantNames.joined(separator: ", "))"
          : "document"
        return "• \(entry.title) — \(detail) (rev \(entry.revision), id \(entry.id))"
      }
      .joined(separator: "\n")

    return toolResult(
      text: summary,
      structuredContent: ["projectPath": index.projectPath, "artifacts": entries]
    )
  }

  /// Returns the current payload of one Studio artifact — the variants as they
  /// are *now*, including edits the user baked in from the canvas.
  ///
  /// This is what makes "let's go with the ghost one" work from the chat: the
  /// agent fetches the variant the user means and implements exactly what they
  /// see, rather than the version it originally filed. Reads the sidecar the
  /// app writes beside the served document; never the app's database.
  private func getStudioArtifact(arguments: [String: Any]) throws -> [String: Any] {
    let id = try requiredString("id", in: arguments)
    let projectPath = optionalString("projectPath", in: arguments)
      ?? ProcessInfo.processInfo.environment["EASEL_PROJECT_PATH"]
      ?? FileManager.default.currentDirectoryPath
    let variantFilter = optionalString("variant", in: arguments).flatMap { $0.isEmpty ? nil : $0 }
    let includeContent = (arguments["includeContent"] as? Bool) ?? false

    guard let index = studioIndex.read(projectPath: projectPath),
          let entry = index.artifacts.first(where: { $0.id == id })
    else {
      throw MCPError.invalidRequest(
        "No Studio artifact with id \(id) in this project. Call easel_list_artifacts to see what exists."
      )
    }
    guard let payloadPath = entry.payloadPath,
          let data = FileManager.default.contents(atPath: payloadPath)
    else {
      throw MCPError.invalidRequest(
        "The payload for artifact \(id) is not available yet; open it in the Designs surface once, or re-file it."
      )
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let artifact = try decoder.decode(StudioArtifact.self, from: data)

    if let variantFilter, artifact.kind == .canvas,
       !artifact.variants.contains(where: { $0.name.caseInsensitiveCompare(variantFilter) == .orderedSame })
    {
      throw MCPError.invalidRequest(
        "Canvas \(id) has no variant named \"\(variantFilter)\". Variants: \(artifact.variantNames.joined(separator: ", "))."
      )
    }

    var structured: [String: Any] = [
      "id": artifact.id,
      "kind": artifact.kind.rawValue,
      "title": artifact.title,
      "revision": artifact.revision,
      "updatedAt": ISO8601DateFormatter().string(from: artifact.displayDate),
    ]
    if let sourcePath = artifact.sourcePath { structured["sourcePath"] = sourcePath }
    if !artifact.props.isEmpty {
      structured["props"] = artifact.props.map { prop -> [String: Any] in
        var object = prop.declaration
        object["name"] = prop.name
        object["cssVariable"] = prop.cssVariableName
        return object
      }
    }

    var summaryLines: [String] = ["\(artifact.title) (\(artifact.kind.rawValue), rev \(artifact.revision), id \(artifact.id))"]
    switch artifact.kind {
    case .canvas:
      structured["variants"] = artifact.variants.map { variant -> [String: Any] in
        let selected = variantFilter.map { $0.caseInsensitiveCompare(variant.name) == .orderedSame } ?? false
        var object: [String: Any] = [
          "name": variant.name,
          "htmlBytes": variant.html.utf8.count,
          "cssBytes": variant.css.utf8.count,
        ]
        if let notes = variant.notes { object["notes"] = notes }
        if selected || includeContent {
          object["html"] = variant.html
          object["css"] = variant.css
        }
        return object
      }
      for variant in artifact.variants {
        let selected = variantFilter.map { $0.caseInsensitiveCompare(variant.name) == .orderedSame } ?? false
        var line = "• \(variant.name)"
        if let notes = variant.notes { line += " — \(notes)" }
        if selected || includeContent {
          line += "\n  html:\n\(variant.html)\n  css:\n\(variant.css)"
        }
        summaryLines.append(line)
      }
      if variantFilter == nil, !includeContent {
        summaryLines.append("Pass variant=<name> for one variant's html/css, or includeContent=true for all. The markup includes any edits the user made in the Designs surface.")
      }
    case .document:
      if includeContent, let html = artifact.html {
        structured["html"] = html
        summaryLines.append(html)
      } else {
        structured["htmlBytes"] = artifact.html?.utf8.count ?? 0
        summaryLines.append("Pass includeContent=true for the document HTML.")
      }
    }

    return toolResult(text: summaryLines.joined(separator: "\n"), structuredContent: structured)
  }

  // MARK: - Argument helpers

  private func studioProvider(toolName: String) throws -> StudioProvider {
    guard let provider = ProcessInfo.processInfo.environment["EASEL_PROVIDER"]
      .flatMap(StudioProvider.init(commandLineValue:))
    else {
      throw MCPError.invalidRequest(
        "\(toolName) is only available inside an Easel-managed Claude or Codex session."
      )
    }
    return provider
  }

  private func studioTitle(_ key: String, in arguments: [String: Any]) throws -> String {
    let value = try requiredString(key, in: arguments)
    guard value.count <= StudioArtifact.Limits.maxTitleLength else {
      throw MCPError.invalidRequest("\(key) is longer than \(StudioArtifact.Limits.maxTitleLength) characters.")
    }
    return value
  }

  /// An explicit id means this is a re-file of an artifact that already exists:
  /// the app upserts on id, so the item refreshes in place instead of a
  /// near-duplicate piling up beside it.
  private func studioIdentifier(in arguments: [String: Any]) -> String {
    optionalString("id", in: arguments).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
  }

  private func studioDimension(_ raw: Any?, label: String, variant: String) -> Double? {
    guard let raw, !(raw is NSNull) else { return nil }
    let value: Double?
    if let number = raw as? NSNumber {
      value = number.doubleValue
    } else if let string = raw as? String {
      value = Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      value = nil
    }
    guard let value, value > 0, value.isFinite else { return nil }
    return value
  }

  private func requiredString(_ key: String, in arguments: [String: Any]) throws -> String {
    guard let value = optionalString(key, in: arguments), !value.isEmpty else {
      throw MCPError.invalidRequest("Missing required string argument: \(key).")
    }
    return value
  }

  private func optionalString(_ key: String, in arguments: [String: Any]) -> String? {
    (arguments[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func toolResult(
    text: String,
    structuredContent: [String: Any],
    isError: Bool = false
  ) -> [String: Any] {
    [
      "content": [
        [
          "type": "text",
          "text": text,
        ],
      ],
      "structuredContent": structuredContent,
      "isError": isError,
    ]
  }

  // MARK: - Tool schemas

  private func artifactToolSchema() -> [String: Any] {
    [
      "name": "easel_artifact",
      "description": """
        Use when the user wants to SEE something rendered rather than read code — "render this \
        report", "mock up the landing page", "draw the flow", "show me a dashboard", "what would \
        the onboarding screen look like" — and it is one page rather than side-by-side variants. \
        Renders a self-contained HTML document in the Designs surface of Easel's canvas pane. \
        Easel serves the document from its own directory on localhost; nothing is written into \
        the project, so this is the right tool for visual answers that must not touch the \
        codebase. The user can point at any element in the rendered page, comment on it, and \
        send that feedback back to you. Call easel_list_artifacts first and pass an existing id \
        when you are refining something already on screen, so the surface updates in place \
        instead of stacking a near-duplicate. Provide a complete document (inline CSS and JS; \
        remote assets are allowed but not fetched by Easel). To make the document tweakable, \
        call `window.dc_set_props({ name: { type: slider|color|select|toggle|text, value, \
        label?, min?, max?, step?, options? } })` at load and read `window.props.<name>` (or \
        implement `window.dc_on_props_changed(props)`) — Easel shows a Tweaks panel with live \
        controls, and saving new defaults rewrites the values in your dc_set_props call. Guard \
        the call with `if (window.dc_set_props)` so the page also works in a plain browser. For \
        side-by-side variants of one component, use easel_design instead.
        """,
      "inputSchema": [
        "type": "object",
        "properties": [
          "title": [
            "type": "string",
            "description": "Short name for the artifact, shown in the surface header (≤120 chars).",
          ],
          "html": [
            "type": "string",
            "description": "The full HTML document. Served verbatim. Limit \(StudioArtifact.Limits.maxDocumentBytes) bytes.",
          ],
          "id": [
            "type": "string",
            "description": "Pass the id of an existing artifact (from easel_list_artifacts or an earlier result) to replace it in place. Omit for a new artifact.",
          ],
        ],
        "required": ["title", "html"],
        "additionalProperties": false,
      ],
    ]
  }

  private func designToolSchema() -> [String: Any] {
    [
      "name": "easel_design",
      "description": """
        Use whenever the user asks to see, compare, mock up, or explore OPTIONS, VERSIONS, or \
        VARIANTS of any UI — "show me 4 versions of this button", "give me a few directions for \
        the card", "compare dense vs airy", "what would the CTA look like as outline vs filled" — \
        instead of editing project files. Lays the variants out side by side on an infinite design \
        canvas in the Designs surface of Easel's canvas pane, without touching the project: the \
        canvas is a scratch surface for deciding before anything is implemented. Each variant is \
        an HTML fragment plus its CSS; Easel isolates each variant's CSS to its own artboard, so \
        write ordinary selectors (`.btn`, `body`, `:root` custom properties all work per \
        variant). Scripts are stripped: variants share one document, so use CSS for hover/focus \
        states and easel_artifact for anything that needs JS. Optionally declare `props` — one \
        shared tweak schema for the whole canvas (sliders, colors, selects, toggles, text). Each \
        prop is exposed to every variant as the CSS custom property `--<name>` (write \
        `var(--radius)` in variant CSS; slider values carry their `unit`), and text/select \
        values are also written into elements marked `data-prop="<name>"`. The user moves the \
        controls in Easel's Tweaks panel and every variant updates live, so the same knob can be \
        compared across variants; when they save new defaults, Easel updates the canvas itself. \
        The user can click any element on any variant, comment, and send that back to you \
        stamped with the variant name; re-file with the same id to update the canvas in place. \
        Call easel_list_artifacts first when refining an existing canvas. Do not edit project \
        files in response to canvas feedback unless the user explicitly asks you to implement a \
        variant.
        """,
      "inputSchema": [
        "type": "object",
        "properties": [
          "component": [
            "type": "string",
            "description": "What is being explored, e.g. \"Primary button\" (≤120 chars). Shown as the canvas title.",
          ],
          "variants": [
            "type": "array",
            "description": "1–\(StudioArtifact.Limits.maxVariants) variants, each rendered on its own artboard.",
            "items": [
              "type": "object",
              "properties": [
                "name": ["type": "string", "description": "Short unique label, e.g. \"ghost\" (≤40 chars)."],
                "html": ["type": "string", "description": "The variant's markup. A fragment; document wrappers and <script> are stripped, <style> is hoisted."],
                "css": ["type": "string", "description": "Optional CSS for this variant (in addition to any <style> in html). Ordinary selectors; Easel scopes them."],
                "notes": ["type": "string", "description": "Optional one-line rationale shown under the artboard (≤500 chars)."],
                "width": ["type": "number", "description": "Optional fixed artboard width in CSS px. Defaults to content width."],
                "height": ["type": "number", "description": "Optional fixed artboard height in CSS px. Defaults to content height."],
              ],
              "required": ["name", "html"],
              "additionalProperties": false,
            ],
          ],
          "props": [
            "type": "object",
            "description": "Optional shared tweak schema, keyed by prop name (a CSS-identifier-safe name, ≤40 chars; up to \(StudioTweakPropParser.maxProps) props). Each value is { type: slider|color|select|toggle|text, value, label?, min?, max?, step?, unit?, options? }. Every prop becomes `--<name>` on every artboard; write variant CSS against var(--<name>). Example: { \"radius\": { \"type\": \"slider\", \"value\": 12, \"min\": 0, \"max\": 32, \"unit\": \"px\" }, \"accent\": { \"type\": \"color\", \"value\": \"#0a84ff\" }, \"label\": { \"type\": \"text\", \"value\": \"Continue\" } }.",
            "additionalProperties": true,
          ],
          "sourcePath": [
            "type": "string",
            "description": "Optional project-relative path of the real component these variants explore (e.g. src/components/Button.tsx). Only used to name the file if the user later asks to implement a variant.",
          ],
          "id": [
            "type": "string",
            "description": "Pass the id of an existing canvas to replace its variants in place. Omit for a new canvas.",
          ],
        ],
        "required": ["component", "variants"],
        "additionalProperties": false,
      ],
    ]
  }

  private func listArtifactsToolSchema() -> [String: Any] {
    [
      "name": "easel_list_artifacts",
      "description": """
        Lists the Studio artifacts and design canvases already filed for this project in Easel, \
        with each one's id, kind, title, variant names, and revision. Call this before \
        easel_artifact or easel_design when the user is refining something already on screen — \
        match their words against the titles and re-file with that id — and whenever they ask \
        what has been rendered or designed so far. Artifacts are shared across every session in \
        the project, Claude and Codex alike.
        """,
      "inputSchema": [
        "type": "object",
        "properties": [
          "projectPath": [
            "type": "string",
            "description": "Project to list artifacts for. Defaults to the current Easel session's project.",
          ],
        ],
        "additionalProperties": false,
      ],
    ]
  }

  private func getArtifactToolSchema() -> [String: Any] {
    [
      "name": "easel_get_artifact",
      "description": """
        Fetches the current content of one Studio artifact or design canvas by id — the variants \
        as they are right now, including edits the user made in the canvas (inline styles, text, \
        removed elements) and saved tweak defaults. Use this when the user picks a variant in \
        conversation ("let's go with the ghost one", "use the second option", "implement that \
        card") — call it with variant=<name>, then implement exactly that html/css in the real \
        component, preserving behaviour and API. Also call it before re-filing an existing \
        canvas so you start from what the user has, not from what you originally filed. Get ids \
        and variant names from easel_list_artifacts.
        """,
      "inputSchema": [
        "type": "object",
        "properties": [
          "id": [
            "type": "string",
            "description": "The artifact id (from easel_list_artifacts or an earlier easel_design / easel_artifact result).",
          ],
          "variant": [
            "type": "string",
            "description": "For a canvas: return this variant's html and css. Case-insensitive.",
          ],
          "includeContent": [
            "type": "boolean",
            "description": "Return the html/css of every variant (or the whole document). Default false: metadata and notes only.",
          ],
          "projectPath": [
            "type": "string",
            "description": "Project the artifact belongs to. Defaults to the current Easel session's project.",
          ],
        ],
        "required": ["id"],
        "additionalProperties": false,
      ],
    ]
  }

  // MARK: - Tool annotations

  /// MCP tool annotations (`readOnlyHint`, `destructiveHint`, `idempotentHint`,
  /// `openWorldHint`) for every tool. Hosts use them to decide how much to
  /// ask: Codex's `writes` approval mode, for one, "prompts for tools that
  /// aren't marked read-only" — so the read-only tools must say so, or a
  /// user on that mode is prompted just to list what exists. All tools are
  /// local (`openWorldHint: false`); none are destructive.
  static let toolAnnotationsByName: [String: [String: Any]] = [
    "easel_artifact": annotations(readOnly: false, destructive: false, idempotent: true),
    "easel_design": annotations(readOnly: false, destructive: false, idempotent: true),
    "easel_list_artifacts": annotations(readOnly: true, destructive: false, idempotent: true),
    "easel_get_artifact": annotations(readOnly: true, destructive: false, idempotent: true),
  ]

  private static func annotations(readOnly: Bool, destructive: Bool, idempotent: Bool) -> [String: Any] {
    [
      "readOnlyHint": readOnly,
      "destructiveHint": destructive,
      "idempotentHint": idempotent,
      "openWorldHint": false,
    ]
  }

  /// Attaches the annotations for a schema's tool name; unknown names pass through.
  static func annotated(_ schema: [String: Any]) -> [String: Any] {
    guard let name = schema["name"] as? String, let annotations = toolAnnotationsByName[name] else {
      return schema
    }
    var annotatedSchema = schema
    annotatedSchema["annotations"] = annotations
    return annotatedSchema
  }

  // MARK: - JSON-RPC plumbing

  private func writeResponse(id: Any, result: [String: Any]) {
    writeJSON([
      "jsonrpc": "2.0",
      "id": id,
      "result": result,
    ])
  }

  private func writeError(id: Any?, code: Int, message: String) {
    var response: [String: Any] = [
      "jsonrpc": "2.0",
      "error": [
        "code": code,
        "message": message,
      ],
    ]
    if let id {
      response["id"] = id
    }
    writeJSON(response)
  }

  private func writeJSON(_ object: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [])
    else {
      // Never silently drop a JSON-RPC message: a dropped response leaves the
      // caller's tool call loading forever. Surface it on stderr (stdout is
      // reserved for the protocol) so the failure is at least diagnosable.
      FileHandle.standardError.write(
        Data("easel mcp-server: failed to serialize a JSON-RPC message\n".utf8)
      )
      return
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
  }
}

enum MCPError: LocalizedError {
  case invalidRequest(String)

  var errorDescription: String? {
    switch self {
    case let .invalidRequest(message):
      return message
    }
  }
}
