# Easel — Agent Instructions

Guidelines for any AI agent working on this codebase.

## AI Providers

Easel supports two interchangeable local CLI providers — **Codex** and **Claude** (Claude Code). The active provider is chosen in Settings, and both drive the same in-app chat/build flow as well as the **Send Handoff** flow. When touching provider, chat, or runtime code, keep both providers working and avoid Codex- or Claude-specific assumptions leaking into shared layers.

## Framework

- Use **SwiftUI** exclusively for all UI code — no UIKit or AppKit unless absolutely necessary
- Prefer declarative patterns over imperative ones

## Concurrency

- Use **modern Swift concurrency** (`async/await`, `Task`, actors, `AsyncSequence`)
- **Never use GCD** (`DispatchQueue`, `DispatchGroup`, etc.)

## State Management

- Use the **`@Observable`** macro for observable state — never `ObservableObject` or `@Published`
- Use `@State`, `@Environment`, and `@Bindable` for SwiftUI view state

## Architecture

- Define all services as **protocol interfaces** so dependencies can be injected and easily mocked/stubbed in tests
- Use **dependency injection** — no singletons or global shared state
- Keep the project **modular**: each feature should live in its own Swift package/module when applicable
- Separate concerns: views, view models, services, and models should be in distinct layers

## Local Persistence

- User-created projects and design systems must remain local and independent of the app install
- Store managed projects under a user-visible, app-independent folder such as `~/Documents/Easel Projects`
- Store managed design systems under a user-visible, app-independent folder such as `~/Documents/Easel Design Systems`
- Do **not** store user project/design-system source files only inside the app bundle, app cache, temporary directories, or app support data that may be removed when the app is deleted
- Each generated project or design system must be self-contained: include its scaffold, metadata, resources, and any copied assets inside that folder at a safe level such as `resources/` and `.easel/`
- When importing external files, copy the selected files/resources into the managed local folder instead of depending on fragile external references

## Testing

- **Always write unit tests** for new code
- Leverage protocol interfaces to create mocks/stubs for testing
- Test files live in `EaselTests/` (unit) and `EaselUITests/` (UI)

## Code Style

- Use **spaces** (not tabs), indent width: **2 spaces**
- Follow Swift API design guidelines for naming
