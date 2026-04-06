# Easel — Project Instructions

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
- Place unit tests in `EaselTests` and UI tests in `EaselUITests`

## Skills

When working on this project, always use the following skills when applicable:

- `/swiftui-pro` — for reviewing and writing SwiftUI code with best practices
- `/swiftui-animation` — for implementing animations, transitions, and shader effects
- `/skills:apple-hig-designer` — for designing UI following Apple's Human Interface Guidelines
- `/releasing-macos-apps` — for releasing, notarizing, and distributing macOS apps

## Code Style

- Use **spaces** (not tabs), indent width: **2 spaces**
- Follow Swift API design guidelines for naming
