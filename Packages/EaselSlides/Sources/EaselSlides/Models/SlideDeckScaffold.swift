//
//  SlideDeckScaffold.swift
//  EaselSlides
//

import Foundation

public enum SlideDeckContract {
  public static let deckAttribute = "data-easel-deck"
  public static let slideAttribute = "data-easel-slide"
  public static let titleAttribute = "data-title"
  public static let templateResourcePath = "resources/SLIDE_TEMPLATE.md"

  public static let authoringSummary = "Keep slides as `section[data-easel-slide]` elements inside one `data-easel-deck` stage. The deck stage must be full-bleed in Easel's 16:9 preview: `html`, `body`, and `[data-easel-deck]` fill the viewport with no body padding, centered card frame, rounded outer deck, border, or box shadow. Each `section[data-easel-slide]` is the slide canvas and must clip to the square 16:9 slide bounds with `overflow: hidden`; do not create an inner rounded card/frame/canvas that represents the slide itself. Reuse the safe slide template in `resources/SLIDE_TEMPLATE.md` for every slide layout. Design every slide against a fixed 1280x720 canvas: all text, charts, footer notes, and controls must fit inside that frame without vertical or horizontal overflow. Keep a safe inset around the content, avoid poster-scale type on dense slides, use `minmax(0, 1fr)` for grid rows/columns that can shrink, and split dense material into another slide instead of letting it clip. Slide content must be visible immediately in thumbnails even if decorative motion is present. Put spacing inside each slide section, and set `data-title` for thumbnail labels when needed."
}

public enum SlideDeckScaffold {
  public static let layoutTemplateCSS = """
        :root {
          --easel-slide-pad: clamp(36px, 4.6vw, 60px);
          --easel-slide-gap: clamp(14px, 2vw, 26px);
          --easel-slide-title: clamp(42px, 6vw, 82px);
          --easel-slide-title-dense: clamp(34px, 4.5vw, 58px);
          --easel-slide-body: clamp(16px, 1.6vw, 22px);
          --easel-slide-body-dense: clamp(14px, 1.35vw, 18px);
        }

        [data-easel-slide] {
          padding: var(--easel-slide-pad);
          align-content: stretch;
        }

        .easel-slide-safe {
          position: relative;
          z-index: 1;
          width: 100%;
          height: 100%;
          min-width: 0;
          min-height: 0;
          display: grid;
          gap: var(--easel-slide-gap);
          overflow: hidden;
        }

        .easel-slide-safe[data-layout="hero"] {
          grid-template-columns: minmax(0, 1fr) minmax(260px, 0.82fr);
          align-items: center;
        }

        .easel-slide-safe[data-layout="content"] {
          grid-template-rows: auto minmax(0, 1fr) auto;
          align-content: stretch;
        }

        .easel-slide-safe[data-density="dense"] {
          --easel-slide-gap: clamp(10px, 1.45vw, 18px);
          --easel-slide-title: var(--easel-slide-title-dense);
          --easel-slide-body: var(--easel-slide-body-dense);
        }

        .easel-slide-stack,
        .easel-slide-header,
        .easel-slide-body,
        .easel-slide-list {
          min-width: 0;
          min-height: 0;
          display: grid;
          gap: clamp(10px, 1.4vw, 18px);
        }

        .easel-slide-header {
          align-content: start;
        }

        .easel-slide-body {
          overflow: hidden;
          align-content: start;
        }

        .easel-slide-grid {
          min-width: 0;
          min-height: 0;
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: clamp(10px, 1.5vw, 18px);
          overflow: hidden;
        }

        .easel-slide-grid[data-columns="3"] {
          grid-template-columns: repeat(3, minmax(0, 1fr));
        }

        .easel-slide-title {
          max-width: 13ch;
          margin: 0;
          font-size: var(--easel-slide-title);
          line-height: 0.96;
          letter-spacing: 0;
          text-wrap: balance;
        }

        .easel-slide-safe[data-density="dense"] .easel-slide-title {
          max-width: 16ch;
        }

        .easel-slide-copy {
          max-width: 62ch;
          margin: 0;
          color: var(--muted);
          font-size: var(--easel-slide-body);
          line-height: 1.32;
        }

        .easel-slide-note {
          margin: 0;
          color: var(--muted);
          font-size: clamp(12px, 1vw, 14px);
          line-height: 1.35;
        }

        @media (max-width: 800px) {
          .easel-slide-safe[data-layout="hero"] {
            grid-template-columns: 1fr;
            align-content: center;
          }

          .easel-slide-grid,
          .easel-slide-grid[data-columns="3"] {
            grid-template-columns: 1fr;
          }
        }
    """

  public static let layoutTemplateMarkdown = """
    # Easel Slide Template

    Use this template for every slide in this deck. It is designed for Easel's fixed 16:9, 1280x720 preview and prevents cropped content.

    ## Required Rules

    - Keep one `main[data-easel-deck]` and one `section[data-easel-slide]` per slide.
    - Put all visible slide content inside `.easel-slide-safe`.
    - Use `data-layout="hero"` for a title-plus-visual slide.
    - Use `data-layout="content"` for dense slides with title, body, and footer rows.
    - Add `data-density="dense"` when a slide has lists, tables, charts, or more than one content group.
    - Do not place large text, lists, or charts directly in the slide section without the safe wrapper.
    - If the content does not fit, split it into another slide instead of shrinking below readable sizes.

    ## CSS

    Add or keep this CSS block in `index.html`:

    ```css
    \(layoutTemplateCSS)
    ```

    ## Hero Slide

    ```html
    <section data-easel-slide data-title="Opening" data-active="true">
      <div class="easel-slide-safe" data-layout="hero">
        <div class="easel-slide-stack">
          <div class="eyebrow">Section label</div>
          <h1 class="easel-slide-title">One clear slide idea.</h1>
          <p class="easel-slide-copy">Keep supporting copy short enough to read in a few seconds.</p>
        </div>
        <div class="easel-slide-body">
          <!-- One visual, chart, or focused supporting block. -->
        </div>
      </div>
    </section>
    ```

    ## Dense Content Slide

    ```html
    <section data-easel-slide data-title="Details">
      <div class="easel-slide-safe" data-layout="content" data-density="dense">
        <div class="easel-slide-header">
          <div class="eyebrow">Section label</div>
          <h1 class="easel-slide-title">Readable hierarchy beats packed detail.</h1>
          <p class="easel-slide-copy">Use one short summary line, then let the structured content carry the slide.</p>
        </div>

        <div class="easel-slide-body">
          <div class="easel-slide-grid" data-columns="3">
            <!-- Keep repeated items compact. -->
          </div>
        </div>

        <p class="easel-slide-note">Footer note, source, or one-line takeaway.</p>
      </div>
    </section>
    ```
    """

  public static func indexHTML(
    title rawTitle: String,
    designSystemDisplayName rawDesignSystemDisplayName: String
  ) -> String {
    let title = escapedHTML(rawTitle)
    let designSystemDisplayName = escapedHTML(rawDesignSystemDisplayName)

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(title)</title>
      <style>
        :root {
          color-scheme: light;
          --accent: #d86f51;
          --ink: #22201d;
          --muted: #6f6a63;
          --surface: #fbfaf8;
          --line: #dedbd5;
        }

        * {
          box-sizing: border-box;
        }

        html,
        body {
          margin: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: #111111;
          color: var(--ink);
          font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }

        body {
          width: 100vw;
          height: 100vh;
          display: block;
        }

        /* Easel slide decks are full-bleed. Put spacing inside slides, not around the deck stage. */
        [data-easel-deck] {
          position: relative;
          width: 100vw;
          height: 100vh;
          overflow: hidden;
          background: var(--surface);
          border: 0;
          border-radius: 0;
          box-shadow: none;
        }

        [data-easel-slide] {
          position: absolute;
          inset: 0;
          width: 100%;
          height: 100%;
          display: grid;
          align-content: center;
          gap: 24px;
          padding: clamp(42px, 5vw, 64px);
          background: var(--surface);
          overflow: hidden;
          border: 0;
          border-radius: 0;
          box-shadow: none;
          clip-path: inset(0);
          contain: paint;
          opacity: 0;
          pointer-events: none;
          transition: opacity 180ms ease;
        }

        [data-easel-slide][data-active="true"] {
          opacity: 1;
          pointer-events: auto;
        }

        \(layoutTemplateCSS)

        .eyebrow {
          color: var(--accent);
          font-size: 16px;
          font-weight: 800;
          letter-spacing: 0;
          text-transform: uppercase;
        }

        h1 {
          max-width: 820px;
          margin: 0;
          font-size: clamp(48px, 7vw, 92px);
          line-height: 0.95;
          letter-spacing: 0;
        }

        p {
          max-width: 760px;
          margin: 0;
          color: var(--muted);
          font-size: clamp(18px, 2vw, 26px);
          line-height: 1.32;
        }

        .grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 16px;
        }

        .point {
          border: 1px solid var(--line);
          border-radius: 8px;
          padding: 22px;
          background: white;
        }

        .point strong {
          display: block;
          margin-bottom: 8px;
          color: var(--ink);
          font-size: 20px;
        }

        .point span {
          color: var(--muted);
          font-size: 16px;
          line-height: 1.4;
        }
      </style>
    </head>
    <body>
      <main data-easel-deck aria-label="Slide deck">
        <section data-easel-slide data-title="Opening" data-active="true">
          <div class="easel-slide-safe" data-layout="hero">
            <div class="easel-slide-stack">
              <div class="eyebrow">Easel · Slide Deck</div>
              <h1 class="easel-slide-title">\(title)</h1>
              <p class="easel-slide-copy">This 16:9 deck is ready for Codex to shape into a complete presentation using the \(designSystemDisplayName) design system.</p>
            </div>
            <div class="easel-slide-body">
              <div class="point">
                <strong>Safe slide template</strong>
                <span>Reuse resources/SLIDE_TEMPLATE.md so every slide fits inside the 1280x720 frame.</span>
              </div>
            </div>
          </div>
        </section>

        <section data-easel-slide data-title="Structure">
          <div class="easel-slide-safe" data-layout="content" data-density="dense">
            <div class="easel-slide-header">
              <div class="eyebrow">Deck Structure</div>
              <h1 class="easel-slide-title">Build every slide from the safe template.</h1>
              <p class="easel-slide-copy">Keep the stage fixed, place content inside the safe wrapper, and split dense material before it clips.</p>
            </div>

            <div class="easel-slide-body">
              <div class="easel-slide-grid">
                <div class="point">
                  <strong>One idea per slide</strong>
                  <span>Keep each section focused so thumbnails stay readable and the large preview stays sharp.</span>
                </div>
                <div class="point">
                  <strong>Stable slide markers</strong>
                  <span>Use section elements with data-easel-slide and data-title for reliable rendering.</span>
                </div>
                <div class="point">
                  <strong>Local resources</strong>
                  <span>Copy images, videos, and supporting assets into resources/ before referencing them.</span>
                </div>
                <div class="point">
                  <strong>1280x720 fit</strong>
                  <span>Use resources/SLIDE_TEMPLATE.md as the reusable layout budget for every slide.</span>
                </div>
              </div>
            </div>

            <p class="easel-slide-note">Template: resources/SLIDE_TEMPLATE.md</p>
          </div>
        </section>
      </main>
      <script src="./deck-stage.js"></script>
    </body>
    </html>
    """
  }

  public static let deckStageJavaScript = """
  (() => {
    const slides = Array.from(document.querySelectorAll("[data-easel-slide]"));
    if (slides.length === 0) {
      return;
    }

    let selectedIndex = Math.max(0, slides.findIndex((slide) => slide.dataset.active === "true"));

    function ensureStageStyle() {
      let style = document.getElementById("easel-slide-deck-stage-style");
      if (!style) {
        style = document.createElement("style");
        style.id = "easel-slide-deck-stage-style";
        document.head.appendChild(style);
      }

      style.textContent = `
        html,
        body {
          width: 100% !important;
          height: 100% !important;
          margin: 0 !important;
          overflow: hidden !important;
        }

        body {
          min-height: 100vh !important;
          display: block !important;
          padding: 0 !important;
        }

        [data-easel-deck] {
          position: relative !important;
          width: 100vw !important;
          height: 100vh !important;
          margin: 0 !important;
          padding: 0 !important;
          overflow: hidden !important;
          border: 0 !important;
          border-radius: 0 !important;
          box-shadow: none !important;
        }

        [data-easel-slide] {
          position: absolute !important;
          inset: 0 !important;
          width: 100% !important;
          height: 100% !important;
          overflow: hidden !important;
          border: 0 !important;
          border-radius: 0 !important;
          box-shadow: none !important;
          clip-path: inset(0) !important;
          contain: paint !important;
        }
      `;
    }

    function selectSlide(index) {
      ensureStageStyle();
      selectedIndex = Math.max(0, Math.min(index, slides.length - 1));
      slides.forEach((slide, slideIndex) => {
        if (slideIndex === selectedIndex) {
          slide.dataset.active = "true";
        } else {
          delete slide.dataset.active;
        }
      });
      window.location.hash = `slide-${selectedIndex + 1}`;
    }

    function indexFromHash() {
      const match = window.location.hash.match(/^#slide-(\\d+)$/);
      if (!match) {
        return null;
      }
      return Number(match[1]) - 1;
    }

    const hashIndex = indexFromHash();
    if (hashIndex !== null) {
      selectSlide(hashIndex);
    } else {
      selectSlide(selectedIndex);
    }

    window.addEventListener("hashchange", () => {
      const nextIndex = indexFromHash();
      if (nextIndex !== null) {
        selectSlide(nextIndex);
      }
    });

    window.addEventListener("keydown", (event) => {
      if (event.key === "ArrowRight" || event.key === "PageDown") {
        selectSlide(selectedIndex + 1);
      } else if (event.key === "ArrowLeft" || event.key === "PageUp") {
        selectSlide(selectedIndex - 1);
      }
    });
  })();
  """

  private static func escapedHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
