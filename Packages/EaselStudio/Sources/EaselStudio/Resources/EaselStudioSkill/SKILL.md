---
name: easel-studio
description: Render UI variants or any visual — mockups, reports, diagrams, dashboards — into the Designs surface of Easel's canvas pane, on a scratch surface that never touches project files. Use when the user asks to see, compare, mock up, or explore options, versions, or variants of a component or screen, asks "what would it look like", or wants a rendered document. Also invoked explicitly as /easel-studio.
user-invocable: true
allowed-tools:
  - mcp__easel__easel_design
  - mcp__easel__easel_artifact
  - mcp__easel__easel_list_artifacts
  - mcp__easel__easel_get_artifact
---

# Easel Studio

The Designs surface is a scratch canvas Easel renders beside this session, in the same pane as the live preview. You render into it; the user points, comments, tweaks, and sends feedback back to you. Nothing you file here touches the project.

## Which tool

- **`easel_design`** — several variants of one component, side by side on an infinite canvas ("show me 4 versions of the primary button", "compare a dense vs airy card"). Each variant is an HTML fragment + CSS; Easel isolates each variant's CSS to its own artboard.
- **`easel_artifact`** — one self-contained HTML document ("render this report", "mock up the landing page", "draw the flow"). Served verbatim; inline CSS/JS is fine.
- **`easel_list_artifacts`** — call first when the user is refining something already on screen; re-file with that id so the canvas updates in place instead of stacking a near-duplicate.
- **`easel_get_artifact`** — the current content of one artifact, *including edits the user made in the canvas*. Call it with `variant=<name>` when the user picks one, and before re-filing an existing canvas so you start from what they have.

## Filing a canvas well

1. Decide the axis of comparison (fill vs outline vs soft; density; tone) — 3–6 variants, each with a short `name` and a one-line `notes` rationale.
2. Write plain CSS per variant (`.btn`, `body`, `:root` variables all work; scripts are stripped).
3. Declare **shared `props`** for the knobs worth comparing across every variant — e.g. `radius` (slider, unit `px`), `accent` (color), `label` (text), `shadow` (toggle) — and reference each one from variant CSS as `var(--<name>)` (text/select props can also fill an element marked `data-prop="<name>"`). A declared prop no variant uses is rejected. The user moves one control and every variant updates.
4. Pass `sourcePath` when you know the real component the variants explore; it is only used if the user later asks to implement one.
5. After filing, say it is in the Designs surface and stop — do not also edit files.

## Handling what comes back

- **Comments, crops, tweak requests** arrive as prompts naming the artifact id (and the variant). Re-file with the same id and change only what was asked. Do not edit project files for these.
- **Edits the user makes with the canvas's Edit tool are already saved into the canvas** — you are not asked to apply them. They are simply part of the variant from then on.
- **Choosing a variant** is the one request that asks for code. It arrives either as an "Implement" prompt from the canvas (it carries the current html/css) or in conversation ("let's go with the ghost one", "the second option", "that card"). In the conversational case call `easel_get_artifact` with `variant=<name>` (map ordinals and descriptions to the variant names from the list), then implement exactly that html/css in the real component, preserving behaviour and public API, following project conventions rather than pasting the markup verbatim, and list the files you changed. If it is unclear which variant they mean, ask.

## Boundaries

Inside Easel, prefer the Designs surface over claude.ai artifacts or a /design skill so the result appears in the pane the user is watching. Never write into the repository as part of iterating on a canvas or artifact.
