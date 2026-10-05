// swift-tools-version: 5.9

// Local override for github.com/lukepistrol/SwiftLintPlugin.
//
// The real plugin declares an `Output` folder it never creates, and Xcode 26.4
// fails any build-tool phase whose declared output folder is missing — which
// breaks every app build through no fault of our code ("Running SwiftLint for
// CodeEditTextView/CodeEditSourceEditor" failures, "The folder “Output”
// doesn't exist."). CodeEditTextView and CodeEditSourceEditor depend on the
// plugin to lint *their own* sources; linting vendored third-party code adds
// nothing to Easel builds, so this stub keeps the package identity and
// products but emits no lint commands at all.
//
// Remove this package (and its reference in Easel.xcodeproj) once upstream
// SwiftLintPlugin creates its declared output folder.

import PackageDescription

let package = Package(
  name: "SwiftLintPlugin",
  platforms: [
    .iOS(.v13),
    .watchOS(.v6),
    .macOS(.v10_15),
    .tvOS(.v13),
  ],
  products: [
    .plugin(
      name: "SwiftLint",
      targets: ["SwiftLint"]
    ),
    .plugin(
      name: "SwiftLintFix",
      targets: ["SwiftLintFix"]
    ),
  ],
  targets: [
    .plugin(
      name: "SwiftLint",
      capability: .buildTool()
    ),
    .plugin(
      name: "SwiftLintFix",
      capability: .command(
        intent: .sourceCodeFormatting(),
        permissions: []
      )
    ),
  ]
)
