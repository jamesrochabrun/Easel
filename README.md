![Easel banner](docs/images/easel-banner.png)

# Easel

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/jamesrochabrun/Easel/actions/workflows/ci.yml/badge.svg)](https://github.com/jamesrochabrun/Easel/actions/workflows/ci.yml)

Easel is a macOS workspace for AI-assisted product design and frontend iteration. It brings a local project library, design-system setup, Claude Code chat, a live web preview with a point-and-click inspector, and slide tooling together in one native SwiftUI app — so you can describe a UI, watch it build, and refine it by clicking directly on the result.

![Easel design library](docs/images/easel-design-library.png)

## What Easel Does

- **Build prototypes by chatting** — Describe what you want and Claude Code builds it in a real working directory. Easel runs the dev server, detects the URL, and shows the result in a live preview next to the chat.
- **Iterate by clicking, not typing paths** — Toggle the inspector (`Cmd+Shift+I`), click any element in the preview, and type an instruction like "make this button bigger." Easel sends that element as context to the chat. Crop a region, queue multiple elements, or edit the backing source file directly.
- **Reusable design systems** — Create a design system once (from a description, an imported `DESIGN.md`, or AI-generated) and reuse it across projects so everything you build stays on-brand.
- **A visual design library** — All your projects and design systems appear as a searchable, filterable grid of thumbnails. Click any one to open it in the workspace.
- **Slide decks** — Create "Slide Deck" projects and get a slide rail, live preview, and a Present menu (in-tab, fullscreen, or new tab).
- **Lives in your menu bar** — Easel stays in the menu bar, with quick access to the window, a floating chat bar, and "Check for Updates."

Everything you create is stored locally and independently of the app, under `~/Documents/Easel Projects/` and `~/Documents/Easel Design Systems/` — so your work survives app updates and uninstalls.

## Requirements

- macOS 26.2 or newer
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) installed and authenticated (Easel delegates auth to the CLI — no API keys to paste)
- For building from source: Xcode 26.4 or newer

## Install

Download the latest signed, notarized DMG from the [**Releases**](https://github.com/jamesrochabrun/Easel/releases/latest) page, open it, and drag **Easel** to your Applications folder. Easel ships with [Sparkle](https://sparkle-project.org), so once installed it updates itself automatically — you can also check manually from the menu bar via **Check for Updates…**.

## Getting Started

1. **Launch Easel.** It opens to the Design Library and adds an icon to your menu bar.
2. **Create a design system** (recommended first step) — see the quick start below, or describe a brand and let Easel generate one.
3. **Create a project** — From the sidebar, name it, pick **Prototype** or **Slide Deck**, choose a fidelity (Wireframe or High Fidelity), and select your design system. Click **Create**.
4. **Chat to build** — Describe the screen or component you want. Claude Code writes the files; Easel runs the server and shows a live preview.
5. **Refine visually** — Press `Cmd+Shift+I`, click an element in the preview, and tell Easel what to change.

### Quick start: import a design system from getdesign.md

The fastest way to start with a polished, on-brand look is to grab a ready-made design system from [getdesign.md](https://getdesign.md) and paste it into Easel.

1. Browse [getdesign.md](https://getdesign.md) and open any design system — for example, [SpaceX](https://getdesign.md/spacex/design-md).
2. In the **DESIGN.md** preview, click the **Copy** button to copy the full `DESIGN.md` contents (YAML front matter included).
3. In Easel, open the **Design System** creator and choose the **Import DESIGN.md** mode.
4. Paste the copied contents into the **"Paste the contents of a DESIGN.md here…"** text area.
5. Create it. Easel saves a spec-compliant `DESIGN.md` plus a derived `catalog.json` to `~/Documents/Easel Design Systems/`, and the design system is immediately available when creating projects.

> Tip: You can also browse for an existing `DESIGN.md` file instead of pasting. If you provide both, the pasted text is used.

## Tips & Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+1` | Show / hide the Design Library |
| `Cmd+B` | Cycle panel layouts (sidebar + chat, sidebar, chat, none) |
| `Cmd+Shift+I` | Toggle the preview inspector |

**Inspector modes:** *Input* (click an element + instruction), *Crop* (drag-select a region), *Context* (queue elements as attachments), and *Edit* (edit the backing source file directly).

## Build From Source

Clone the repository and open `Easel.xcodeproj` in Xcode, then build the shared `Easel` scheme.

Command-line build:

```sh
xcodebuild \
  -project Easel.xcodeproj \
  -scheme Easel \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  build
```

Run the package tests with Xcode so CodeEdit package dependencies resolve correctly:

```sh
cd Packages/EaselChat
xcodebuild \
  -scheme EaselChat-Package \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  test
```

## Architecture

- `Easel/` contains the macOS app target, app delegate, status item, window controllers, and canvas shell.
- `Packages/EaselKit/` contains shared app state, domain models, and protocol interfaces.
- `Packages/EaselChat/` contains the chat panel, project/design-system managers, design library, and resource browser.
- `Packages/EaselClaudeCodeUI/` contains reusable Claude/Codex chat UI, storage, runtime, and permission-service integration.
- `Packages/EaselServerManager/` manages local development server processes and URL detection.
- `Packages/EaselWebInspector/` contains the embedded web preview inspector.
- `Packages/EaselPreview/` contains the preview panel shell.
- `Packages/EaselSlides/` contains slide-deck scaffolding and preview support.

## Installation And Updates (Maintainers)

Signed releases are distributed from GitHub Releases. Sparkle is integrated for automatic updates using EdDSA signature verification and the root `appcast.xml` feed. Pushing a `v*` tag triggers the release workflow, which archives, signs, notarizes, builds a DMG, and publishes the release.

Release automation expects these GitHub secrets:

- `CERTIFICATE_BASE64`
- `CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `TEAM_ID`
- `APPLE_ID`
- `APP_PASSWORD`
- `SPARKLE_PRIVATE_KEY`

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Easel is available under the MIT license. See [LICENSE](LICENSE).
</content>
</invoke>
