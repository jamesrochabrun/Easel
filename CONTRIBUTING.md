# Contributing

## Setup

1. Install macOS 26.2 or newer and Xcode 26.4 or newer.
2. Install and authenticate the Claude Code CLI.
3. Clone the repository.
4. Open `Easel.xcodeproj`.
5. Build the shared `Easel` scheme.

## Tests

Build and test the app scheme:

```sh
xcodebuild \
  -project Easel.xcodeproj \
  -scheme Easel \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  test
```

Run package tests through Xcode, not plain `swift test`:

```sh
cd Packages/EaselChat
xcodebuild \
  -scheme EaselChat-Package \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  test
```

## Code Style

- Use SwiftUI for UI code.
- Use modern Swift concurrency with `async`/`await`, `Task`, actors, and `AsyncSequence`.
- Do not use GCD APIs such as `DispatchQueue` or `DispatchGroup`.
- Use `@Observable` for observable state; do not introduce `ObservableObject` or `@Published`.
- Define services behind protocols and inject dependencies.
- Keep user-created projects and design systems in user-visible, app-independent folders.
- Use spaces with 2-space indentation.
- Add focused unit tests for new behavior.
