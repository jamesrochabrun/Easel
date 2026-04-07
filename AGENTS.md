# Easel — Agent Instructions

Guidelines for any AI agent working on this codebase.

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

## Testing

- **Always write unit tests** for new code
- Leverage protocol interfaces to create mocks/stubs for testing
- Test files live in `EaselTests/` (unit) and `EaselUITests/` (UI)

## Code Style

- Use **spaces** (not tabs), indent width: **2 spaces**
- Follow Swift API design guidelines for naming
