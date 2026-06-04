//
//  SlideDeckScaffold.swift
//  EaselSlides
//

import Foundation

public enum SlideDeckContract {
  public static let deckAttribute = "data-easel-deck"
  public static let slideAttribute = "data-easel-slide"
  public static let titleAttribute = "data-title"

  public static let authoringSummary = "Keep slides as `section[data-easel-slide]` elements inside a `data-easel-deck` stage, preserve a 16:9 slide canvas, and set `data-title` for thumbnail labels when needed."
}

public enum SlideDeckScaffold {
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
          min-height: 100%;
          background: #111111;
          color: var(--ink);
          font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }

        body {
          min-height: 100vh;
          display: grid;
          place-items: center;
        }

        [data-easel-deck] {
          position: relative;
          width: min(100vw, calc(100vh * 16 / 9));
          aspect-ratio: 16 / 9;
          overflow: hidden;
          background: var(--surface);
          box-shadow: 0 30px 90px rgb(0 0 0 / 0.30);
        }

        [data-easel-slide] {
          position: absolute;
          inset: 0;
          display: grid;
          align-content: center;
          gap: 24px;
          padding: clamp(48px, 7vw, 92px);
          background: var(--surface);
          opacity: 0;
          pointer-events: none;
          transition: opacity 180ms ease;
        }

        [data-easel-slide][data-active="true"] {
          opacity: 1;
          pointer-events: auto;
        }

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
          font-size: clamp(56px, 8vw, 112px);
          line-height: 0.95;
          letter-spacing: 0;
        }

        p {
          max-width: 760px;
          margin: 0;
          color: var(--muted);
          font-size: clamp(22px, 2.4vw, 34px);
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
          <div class="eyebrow">Codex Design · Slide Deck</div>
          <h1>\(title)</h1>
          <p>This 16:9 deck is ready for Codex to shape into a complete presentation using the \(designSystemDisplayName) design system.</p>
        </section>

        <section data-easel-slide data-title="Structure">
          <div class="eyebrow">Deck Structure</div>
          <div class="grid">
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
              <strong>16:9 canvas</strong>
              <span>Design each slide for a fixed presentation frame rather than a scrolling webpage.</span>
            </div>
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

    function selectSlide(index) {
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
