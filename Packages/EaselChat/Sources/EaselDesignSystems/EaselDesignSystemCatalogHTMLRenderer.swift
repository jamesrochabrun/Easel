//
//  EaselDesignSystemCatalogHTMLRenderer.swift
//  EaselChat
//

import Foundation

enum EaselDesignSystemCatalogHTMLRenderer {
  static func html(title: String, blurb: String) -> String {
    let escapedTitle = escapedHTML(title)
    let escapedBlurb = escapedHTML(blurb)

    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(escapedTitle)</title>
      <script>
        (() => {
          const validModes = new Set(["system", "light", "dark"]);
          let mode = "system";
          try {
            mode = localStorage.getItem("easel-design-system-theme") || "system";
          } catch (error) {
            mode = "system";
          }
          document.documentElement.dataset.themeMode = validModes.has(mode) ? mode : "system";
        })();
      </script>
      <style>
        :root {
          color-scheme: light;
          --ink: #20231f;
          --muted: #5f685f;
          --soft: #7d877e;
          --surface: #f7f8f4;
          --panel: #ffffff;
          --panel-soft: #eef1eb;
          --line: #d7ddd2;
          --accent: #53635b;
          --warning: #9b640f;
          --shadow: rgb(28 32 29 / 0.08);
          /* Thumbnails hold .fig schematics + exported art, which are authored for
             a light canvas; render them on a neutral light surface so exported
             content stays legible inside the surrounding UI. */
          --thumb-bg: #f4f4f2;
        }

        @media (prefers-color-scheme: dark) {
          :root:not([data-theme-mode="light"]) {
            color-scheme: dark;
            --ink: #f1f3f0;
            --muted: #aeb7b0;
            --soft: #747c76;
            --surface: #0d0f0e;
            --panel: #151716;
            --panel-soft: #1b1e1c;
            --line: #2e332f;
            --accent: #aeb7b0;
            --warning: #d68e3a;
            --shadow: rgb(0 0 0 / 0.24);
          }
        }

        :root[data-theme-mode="dark"] {
          color-scheme: dark;
          --ink: #f1f3f0;
          --muted: #aeb7b0;
          --soft: #747c76;
          --surface: #0d0f0e;
          --panel: #151716;
          --panel-soft: #1b1e1c;
          --line: #2e332f;
          --accent: #aeb7b0;
          --warning: #d68e3a;
          --shadow: rgb(0 0 0 / 0.24);
        }

        :root[data-theme-mode="light"] {
          color-scheme: light;
          --ink: #20231f;
          --muted: #5f685f;
          --soft: #7d877e;
          --surface: #f7f8f4;
          --panel: #ffffff;
          --panel-soft: #eef1eb;
          --line: #d7ddd2;
          --accent: #53635b;
          --warning: #9b640f;
          --shadow: rgb(28 32 29 / 0.08);
        }

        * { box-sizing: border-box; }

        body {
          margin: 0;
          min-height: 100vh;
          font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          color: var(--ink);
          background: var(--surface);
        }

        main {
          width: min(1040px, calc(100vw - 40px));
          margin: 0 auto;
          padding: 64px 0;
        }

        header { margin-bottom: 30px; }

        .header-top {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 24px;
        }

        .heading { max-width: 820px; min-width: 0; }

        h1 {
          margin: 0 0 12px;
          font-size: clamp(30px, 4.5vw, 44px);
          font-weight: 600;
          letter-spacing: 0;
          line-height: 1.02;
        }

        .blurb, .empty {
          margin: 0;
          color: var(--muted);
          font-size: 16px;
          line-height: 1.55;
        }

        .summary { margin: 10px 0 0; color: var(--soft); font-size: 14px; line-height: 1.5; }

        .theme-toggle {
          display: grid;
          grid-template-columns: repeat(3, minmax(58px, 1fr));
          gap: 2px;
          flex: 0 0 auto;
          padding: 3px;
          border: 1px solid var(--line);
          border-radius: 8px;
          background: var(--panel-soft);
        }

        .theme-toggle button {
          appearance: none;
          border: 0;
          border-radius: 6px;
          padding: 6px 10px;
          background: transparent;
          color: var(--muted);
          font: inherit;
          font-size: 12px;
          line-height: 1.2;
          cursor: pointer;
        }

        .theme-toggle button:hover {
          color: var(--ink);
        }

        .theme-toggle button[aria-pressed="true"] {
          background: var(--panel);
          color: var(--ink);
          box-shadow: 0 1px 2px var(--shadow);
        }

        .disclaimer {
          margin: 18px 0 0;
          padding: 12px 16px;
          border: 1px solid var(--line);
          border-left: 3px solid var(--accent);
          border-radius: 8px;
          background: var(--panel-soft);
          color: var(--muted);
          font-size: 14px;
          line-height: 1.5;
        }

        .diagnostics {
          margin-top: 16px;
          padding: 13px 15px;
          border: 1px solid var(--line);
          border-radius: 10px;
          background: var(--panel-soft);
          color: var(--muted);
          font-size: 13px;
          line-height: 1.5;
        }
        .diagnostics ul { margin: 8px 0 0; padding: 0; list-style: none; }
        .diagnostics li { position: relative; padding-left: 22px; margin-top: 6px; color: var(--soft); line-height: 1.45; }
        .diagnostics li::before { content: "\\26A0"; position: absolute; left: 0; color: var(--warning); }

        section.block { margin-top: 44px; }

        section.block > h2 {
          margin: 0 0 4px;
          font-size: 13px;
          letter-spacing: 0;
          text-transform: uppercase;
          color: var(--soft);
        }
        section.block > .count { margin: 0 0 18px; color: var(--soft); font-size: 13px; }

        .hero {
          margin-top: 28px;
          border: 1px solid var(--line);
          border-radius: 12px;
          overflow: hidden;
          background: var(--panel-soft);
        }
        .hero img { display: block; width: 100%; height: auto; }

        .swatches {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
          gap: 14px;
        }
        .swatch { border: 1px solid var(--line); border-radius: 10px; overflow: hidden; background: var(--panel); }
        .swatch .chip { height: 72px; }
        .swatch .meta { padding: 10px 12px; }
        .swatch .meta .name { font-size: 13px; font-weight: 600; }
        .swatch .meta .hex { font-size: 12px; color: var(--soft); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

        .specimens { display: flex; flex-direction: column; gap: 10px; }
        .specimen {
          border: 1px solid var(--line);
          border-radius: 10px;
          padding: 16px 18px;
          background: var(--panel);
        }
        .specimen .sample { margin: 0; line-height: 1.2; }
        .specimen .label { margin: 8px 0 0; font-size: 12px; color: var(--soft); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

        .scale { display: flex; flex-direction: column; gap: 8px; }
        .scale-row { display: flex; align-items: center; gap: 14px; }
        .scale-row .bar { height: 14px; border-radius: 4px; background: var(--accent); min-width: 2px; }
        .scale-row .radius-box { height: 36px; width: 56px; border: 2px solid var(--accent); background: var(--panel-soft); }
        .scale-row .name { font-size: 13px; min-width: 120px; }
        .scale-row .value { font-size: 12px; color: var(--soft); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

        .chips { display: flex; flex-wrap: wrap; gap: 8px; }
        .chip-pill {
          border: 1px solid var(--line);
          border-radius: 999px;
          padding: 6px 12px;
          font-size: 13px;
          background: var(--panel);
        }
        .chip-pill .k { color: var(--soft); }

        .families {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
          gap: 14px;
        }
        .family {
          border: 1px solid var(--line);
          border-radius: 10px;
          background: var(--panel);
          overflow: hidden;
          display: flex;
          flex-direction: column;
        }
        .family .preview { aspect-ratio: 16 / 10; background: var(--thumb-bg); display: flex; align-items: center; justify-content: center; overflow: hidden; }
        .family .preview img { max-width: 100%; max-height: 100%; }
        .placeholder { width: 30px; height: 30px; border: 1.5px dashed var(--soft); border-radius: 7px; opacity: 0.7; }
        .scene { width: 100%; height: 100%; display: block; }
        .family .body { padding: 14px 16px; }
        .family h3 { margin: 0; font-size: 15px; }
        .family .sub { margin: 4px 0 0; font-size: 12px; color: var(--soft); }
        .family .props { margin-top: 10px; display: flex; flex-wrap: wrap; gap: 6px; }

        .gallery {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
          gap: 12px;
        }
        .tile { border: 1px solid var(--line); border-radius: 10px; overflow: hidden; background: var(--panel); }
        .tile .thumb { aspect-ratio: 4 / 3; background: var(--thumb-bg); display: flex; align-items: center; justify-content: center; }
        .tile .thumb img { max-width: 100%; max-height: 100%; }
        .tile .caption { padding: 8px 10px; font-size: 12px; }
        .tile .caption .src { color: var(--soft); }

        .empty {
          margin-top: 32px;
          padding: 24px;
          border: 1px solid var(--line);
          border-radius: 10px;
          background: var(--panel);
        }

        @media (max-width: 680px) {
          main {
            width: min(100% - 28px, 1040px);
            padding: 36px 0;
          }

          .header-top {
            flex-direction: column;
            gap: 16px;
          }

          .theme-toggle {
            width: 100%;
          }
        }
      </style>
    </head>
    <body>
      <main>
        <header>
          <div class="header-top">
            <div class="heading">
              <h1>\(escapedTitle)</h1>
              <p class="blurb">\(escapedBlurb)</p>
            </div>
            <div class="theme-toggle" role="group" aria-label="Theme">
              <button type="button" data-theme-option="system" aria-pressed="true">System</button>
              <button type="button" data-theme-option="light" aria-pressed="false">Light</button>
              <button type="button" data-theme-option="dark" aria-pressed="false">Dark</button>
            </div>
          </div>
          <p id="summary" class="summary">Loading local catalog…</p>
          <p id="disclaimer" class="disclaimer" hidden></p>
          <div id="diagnostics" class="diagnostics" hidden></div>
        </header>
        <div id="content"></div>
      </main>
      <script>
        const contentEl = document.getElementById("content");
        const summaryEl = document.getElementById("summary");
        const disclaimerEl = document.getElementById("disclaimer");
        const diagnosticsEl = document.getElementById("diagnostics");
        const themeStorageKey = "easel-design-system-theme";
        const themeModes = ["system", "light", "dark"];
        const themeButtons = Array.from(document.querySelectorAll("[data-theme-option]"));
        const systemThemeQuery = window.matchMedia
          ? window.matchMedia("(prefers-color-scheme: dark)")
          : null;
        let attempts = 0;

        function validThemeMode(mode) {
          return themeModes.includes(mode) ? mode : "system";
        }

        function storedThemeMode() {
          try {
            return localStorage.getItem(themeStorageKey);
          } catch (error) {
            return null;
          }
        }

        function persistThemeMode(mode) {
          try {
            localStorage.setItem(themeStorageKey, mode);
          } catch (error) {
            return;
          }
        }

        function effectiveThemeMode(mode) {
          if (mode === "system") {
            return systemThemeQuery && systemThemeQuery.matches ? "dark" : "light";
          }
          return mode;
        }

        function applyThemeMode(mode, shouldPersist = false) {
          const nextMode = validThemeMode(mode);
          document.documentElement.dataset.themeMode = nextMode;
          document.documentElement.dataset.effectiveTheme = effectiveThemeMode(nextMode);
          for (const button of themeButtons) {
            const selected = button.dataset.themeOption === nextMode;
            button.setAttribute("aria-pressed", selected ? "true" : "false");
          }
          if (shouldPersist) persistThemeMode(nextMode);
        }

        for (const button of themeButtons) {
          button.addEventListener("click", () => {
            applyThemeMode(button.dataset.themeOption, true);
          });
        }

        if (systemThemeQuery) {
          const handleSystemThemeChange = () => {
            if (document.documentElement.dataset.themeMode === "system") {
              applyThemeMode("system");
            }
          };
          if (systemThemeQuery.addEventListener) {
            systemThemeQuery.addEventListener("change", handleSystemThemeChange);
          } else if (systemThemeQuery.addListener) {
            systemThemeQuery.addListener(handleSystemThemeChange);
          }
        }

        applyThemeMode(document.documentElement.dataset.themeMode || storedThemeMode());

        function el(tag, opts = {}) {
          const node = document.createElement(tag);
          if (opts.className) node.className = opts.className;
          if (opts.text != null) node.textContent = opts.text;
          if (opts.html != null) node.innerHTML = opts.html;
          return node;
        }

        function section(title, count) {
          const s = el("section", { className: "block" });
          s.append(el("h2", { text: title }));
          if (count != null) s.append(el("p", { className: "count", text: count }));
          return s;
        }

        function renderColors(tokens) {
          const colors = (tokens && tokens.colors) || [];
          if (!colors.length) return null;
          const s = section("Colors", colors.length + (colors.length === 1 ? " token" : " tokens"));
          const grid = el("div", { className: "swatches" });
          for (const c of colors) {
            const sw = el("div", { className: "swatch" });
            const chip = el("div", { className: "chip" });
            chip.style.background = c.hex || "#ffffff";
            const meta = el("div", { className: "meta" });
            meta.append(el("div", { className: "name", text: c.name || "Color" }));
            meta.append(el("div", { className: "hex", text: c.hex || "" }));
            sw.append(chip, meta);
            grid.append(sw);
          }
          s.append(grid);
          return s;
        }

        function renderTypography(tokens) {
          const type = (tokens && tokens.typography) || [];
          if (!type.length) return null;
          const s = section("Typography", type.length + (type.length === 1 ? " style" : " styles"));
          const list = el("div", { className: "specimens" });
          for (const t of type) {
            const item = el("div", { className: "specimen" });
            const sample = el("p", { className: "sample", text: t.name || t.fontFamily || "Aa Bb Cc" });
            if (t.fontFamily) sample.style.fontFamily = '"' + t.fontFamily + '", system-ui, sans-serif';
            if (t.fontSize) sample.style.fontSize = Math.min(Math.max(t.fontSize, 11), 48) + "px";
            const detail = [t.fontFamily, t.fontStyle, t.fontSize ? Math.round(t.fontSize) + "px" : null].filter(Boolean).join(" · ");
            item.append(sample, el("p", { className: "label", text: detail }));
            list.append(item);
          }
          s.append(list);
          return s;
        }

        function renderScale(title, items, kind) {
          if (!items || !items.length) return null;
          const s = section(title, items.length + (items.length === 1 ? " token" : " tokens"));
          const scale = el("div", { className: "scale" });
          for (const item of items) {
            const row = el("div", { className: "scale-row" });
            row.append(el("div", { className: "name", text: item.name || (kind === "radius" ? "Radius" : "Spacing") }));
            if (kind === "radius") {
              const box = el("div", { className: "radius-box" });
              box.style.borderRadius = Math.min(item.value || 0, 28) + "px";
              row.append(box);
            } else {
              const bar = el("div", { className: "bar" });
              bar.style.width = Math.min(Math.max(item.value || 0, 2), 320) + "px";
              row.append(bar);
            }
            row.append(el("div", { className: "value", text: Math.round(item.value || 0) + (item.unit || "px") }));
            scale.append(row);
          }
          s.append(scale);
          return s;
        }

        function renderEffects(tokens) {
          const effects = (tokens && tokens.effects) || [];
          if (!effects.length) return null;
          const s = section("Effects", effects.length + (effects.length === 1 ? " token" : " tokens"));
          const chips = el("div", { className: "chips" });
          for (const e of effects) {
            const pill = el("div", { className: "chip-pill" });
            pill.append(document.createTextNode((e.name || "Effect") + " "));
            pill.append(el("span", { className: "k", text: e.kind || "" }));
            chips.append(pill);
          }
          s.append(chips);
          return s;
        }

        const SVG_NS = "http://www.w3.org/2000/svg";

        function buildScene(scene) {
          const svg = document.createElementNS(SVG_NS, "svg");
          svg.setAttribute("viewBox", `0 0 ${scene.width} ${scene.height}`);
          svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
          svg.classList.add("scene");
          for (const layer of scene.layers || []) {
            let node = null;
            if (layer.kind === "rect") {
              node = document.createElementNS(SVG_NS, "rect");
              node.setAttribute("x", layer.x);
              node.setAttribute("y", layer.y);
              node.setAttribute("width", layer.width);
              node.setAttribute("height", layer.height);
              if (layer.cornerRadius) node.setAttribute("rx", layer.cornerRadius);
              node.setAttribute("fill", layer.fill || "none");
              if (layer.stroke) {
                node.setAttribute("stroke", layer.stroke);
                node.setAttribute("stroke-width", layer.strokeWidth || 1);
              }
            } else if (layer.kind === "text") {
              node = document.createElementNS(SVG_NS, "text");
              const size = Math.min(layer.fontSize || 12, 64);
              node.setAttribute("x", layer.x);
              node.setAttribute("y", layer.y + size * 0.82);
              node.setAttribute("font-size", size);
              node.setAttribute("fill", layer.textColor || "#1b1b1b");
              node.setAttribute("font-family", "ui-sans-serif, system-ui, sans-serif");
              if (layer.fontWeight && /bold|semi|medium|black|heavy/i.test(layer.fontWeight)) {
                node.setAttribute("font-weight", "600");
              }
              node.textContent = (layer.text || "").slice(0, 80);
            } else if (layer.kind === "image") {
              node = document.createElementNS(SVG_NS, "image");
              node.setAttribute("x", layer.x);
              node.setAttribute("y", layer.y);
              node.setAttribute("width", layer.width);
              node.setAttribute("height", layer.height);
              node.setAttribute("href", layer.imagePath);
              node.setAttribute("preserveAspectRatio", "xMidYMid slice");
            } else if (layer.kind === "path") {
              const g = document.createElementNS(SVG_NS, "g");
              g.setAttribute("transform", `translate(${layer.x}, ${layer.y})`);
              const p = document.createElementNS(SVG_NS, "path");
              p.setAttribute("d", layer.path);
              p.setAttribute("fill", layer.fill || "#888");
              if (layer.opacity != null) g.setAttribute("opacity", layer.opacity);
              g.append(p);
              svg.append(g);
              continue;
            }
            if (node) {
              if (layer.opacity != null) node.setAttribute("opacity", layer.opacity);
              svg.append(node);
            }
          }
          return svg;
        }

        function fillPreview(container, scene, label) {
          if (scene && Array.isArray(scene.layers) && scene.layers.length) {
            container.append(buildScene(scene));
          } else {
            container.append(el("div", { className: "placeholder" }));
          }
        }

        function renderFamilies(catalog) {
          const families = catalog.componentFamilies || [];
          if (!families.length) return null;
          const s = section("Component families", families.length + (families.length === 1 ? " family" : " families"));
          const grid = el("div", { className: "families" });
          for (const f of families) {
            const card = el("div", { className: "family" });
            const preview = el("div", { className: "preview" });
            fillPreview(preview, f.preview, f.title);
            const body = el("div", { className: "body" });
            body.append(el("h3", { text: f.title || "Component" }));
            const sub = [f.category, f.sourcePage, (f.variantCount || 0) + (f.variantCount === 1 ? " variant" : " variants")].filter(Boolean).join(" · ");
            body.append(el("p", { className: "sub", text: sub }));
            const props = el("div", { className: "props" });
            for (const p of (f.variantProperties || [])) {
              const pill = el("div", { className: "chip-pill" });
              pill.append(el("span", { className: "k", text: (p.name || "") + ": " }));
              pill.append(document.createTextNode((p.values || []).slice(0, 4).join(" · ")));
              props.append(pill);
            }
            if (props.childNodes.length) body.append(props);
            card.append(preview, body);
            grid.append(card);
          }
          s.append(grid);
          return s;
        }

        function renderExamples(items) {
          if (!items || !items.length) return null;
          const s = section("Examples", String(items.length));
          const grid = el("div", { className: "gallery" });
          for (const item of items) {
            const tile = el("div", { className: "tile" });
            const thumb = el("div", { className: "thumb" });
            fillPreview(thumb, item.preview, item.title);
            const caption = el("div", { className: "caption" });
            caption.append(el("div", { text: item.title || "Frame" }));
            if (item.sourcePage) caption.append(el("div", { className: "src", text: item.sourcePage }));
            tile.append(thumb, caption);
            grid.append(tile);
          }
          s.append(grid);
          return s;
        }

        function assetLabel(name) {
          if (!name || /^[0-9a-f]{12,}$/i.test(name)) return "Image";
          return name;
        }

        function renderAssets(items) {
          if (!items || !items.length) return null;
          const images = items.filter((item) => item.kind !== "thumbnail" && item.relativePath);
          if (!images.length) return null;
          const s = section("Assets", String(images.length));
          const countEl = s.querySelector(".count");
          const grid = el("div", { className: "gallery" });
          let shown = images.length;
          for (const item of images) {
            const tile = el("div", { className: "tile" });
            const thumb = el("div", { className: "thumb" });
            const img = el("img");
            img.alt = assetLabel(item.name);
            img.loading = "lazy";
            // Some catalogs reference exported art that was not written to disk;
            // drop those tiles instead of showing a broken-image glyph.
            img.onerror = () => {
              tile.remove();
              shown -= 1;
              if (shown <= 0) { s.remove(); return; }
              if (countEl) countEl.textContent = String(shown);
            };
            img.src = item.relativePath;
            thumb.append(img);
            const caption = el("div", { className: "caption" });
            caption.append(el("div", { text: assetLabel(item.name) }));
            tile.append(thumb, caption);
            grid.append(tile);
          }
          s.append(grid);
          return s;
        }

        function renderDiagnostics(diag) {
          if (!diag) { diagnosticsEl.hidden = true; return; }
          diagnosticsEl.replaceChildren();
          const parts = [];
          if (diag.parserName) parts.push("Parsed with " + diag.parserName + (diag.parserVersion ? " " + diag.parserVersion : ""));
          if (diag.totalNodeCount) parts.push(diag.totalNodeCount.toLocaleString() + " nodes");
          if (diag.failedCount) parts.push(diag.failedCount + " failed");
          if (parts.length) diagnosticsEl.append(el("div", { text: parts.join(" · ") }));
          if (diag.warnings && diag.warnings.length) {
            const ul = el("ul");
            for (const w of diag.warnings) ul.append(el("li", { text: w }));
            diagnosticsEl.append(ul);
          }
          diagnosticsEl.hidden = diagnosticsEl.childNodes.length === 0;
        }

        function renderCatalog(catalog) {
          summaryEl.textContent = catalog.summary || "Local design system.";
          if (catalog.disclaimer) {
            disclaimerEl.textContent = catalog.disclaimer;
            disclaimerEl.hidden = false;
          }
          renderDiagnostics(catalog.sourceDiagnostics);

          contentEl.replaceChildren();
          const tokens = catalog.tokens;

          if (catalog.heroThumbnailPath) {
            const hero = el("div", { className: "hero" });
            const img = el("img");
            img.src = catalog.heroThumbnailPath;
            img.alt = catalog.title || catalog.name || "";
            hero.append(img);
            contentEl.append(hero);
          }

          const sections = [
            renderColors(tokens),
            renderTypography(tokens),
            renderScale("Spacing", tokens && tokens.spacing, "spacing"),
            renderScale("Radii", tokens && tokens.radii, "radius"),
            renderEffects(tokens),
            renderFamilies(catalog),
            renderExamples(catalog.examples),
            renderAssets(catalog.assets),
          ].filter(Boolean);

          if (!sections.length) {
            contentEl.append(el("div", {
              className: "empty",
              text: catalog.summary || "No tokens or component families were extracted from this .fig.",
            }));
            return;
          }
          for (const s of sections) contentEl.append(s);
        }

        async function loadCatalog() {
          attempts += 1;
          try {
            const response = await fetch(".easel/catalog.json", { cache: "no-store" });
            if (!response.ok) throw new Error("Catalog is not ready");
            renderCatalog(await response.json());
          } catch (error) {
            if (attempts < 60) {
              summaryEl.textContent = "Creating local catalog…";
              setTimeout(loadCatalog, 1000);
              return;
            }
            summaryEl.textContent = "Catalog not available yet.";
            contentEl.replaceChildren(el("div", {
              className: "empty",
              text: "The .fig file was copied locally. The generated catalog will appear after extraction writes .easel/catalog.json.",
            }));
          }
        }

        loadCatalog();
      </script>
    </body>
    </html>
    """
  }

  private static func escapedHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
  }
}
