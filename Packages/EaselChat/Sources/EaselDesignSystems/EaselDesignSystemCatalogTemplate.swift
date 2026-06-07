//
//  EaselDesignSystemCatalogTemplate.swift
//  EaselDesignSystems
//
//  The app-owned canvas renderer for a design system. It is a single,
//  self-contained `index.html` that fetches `.easel/catalog.json` (the
//  schemaVersion 3 design-token catalog) and renders it as a refined,
//  single-column editorial showcase with a light/dark toggle:
//  colors, typography, spacing, radii, an elevation/shadow carousel,
//  interaction states, iconography, and live basic components.
//

import Foundation

public enum EaselDesignSystemCatalogTemplate {
  public static let version = 3
  public static let marker = "data-easel-design-system-template=\"3\""

  public static func indexHTML(name: String, summary: String) -> String {
    let title = escapedHTML(name)
    let fallbackName = scriptString(name)
    let fallbackSummary = scriptString(summary)

    return """
    <!doctype html>
    <html lang="en" \(marker)>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(title) — Design System</title>
      <style>
        :root {
          --ui: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
          --accent: #4f46e5;
          --maxw: 940px;
        }

        :root, [data-theme="light"] {
          color-scheme: light;
          --page: #f5f5f3;
          --surface: #ffffff;
          --surface-2: #f1f1ee;
          --ink: #15171c;
          --muted: #6b6f78;
          --faint: #9a9ea7;
          --line: #e6e6e1;
          --line-strong: #d6d6cf;
          --shadow-ambient: 0 10px 30px rgba(17, 19, 24, 0.06);
        }

        [data-theme="dark"] {
          color-scheme: dark;
          --page: #0c0d10;
          --surface: #16181d;
          --surface-2: #1c1f26;
          --ink: #f2f3f5;
          --muted: #9aa0ab;
          --faint: #6b7079;
          --line: #272a31;
          --line-strong: #343843;
          --shadow-ambient: 0 14px 40px rgba(0, 0, 0, 0.45);
        }

        * { box-sizing: border-box; }

        html { scroll-behavior: smooth; }

        body {
          margin: 0;
          min-height: 100vh;
          color: var(--ink);
          background: var(--page);
          font-family: var(--ui);
          -webkit-font-smoothing: antialiased;
          text-rendering: optimizeLegibility;
          transition: background 240ms ease, color 240ms ease;
        }

        button { font: inherit; cursor: pointer; }

        .wrap {
          width: min(var(--maxw), calc(100vw - 48px));
          margin: 0 auto;
          padding: 40px 0 120px;
        }

        /* ---- Masthead ---- */
        .topbar {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          padding-bottom: 30px;
        }

        .brand {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          color: var(--muted);
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 0.16em;
          text-transform: uppercase;
        }

        .brand-dot {
          width: 12px;
          height: 12px;
          border-radius: 50%;
          background: var(--accent);
          box-shadow: 0 0 0 4px color-mix(in srgb, var(--accent) 18%, transparent);
        }

        .theme-toggle {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          height: 38px;
          padding: 0 14px;
          border: 1px solid var(--line-strong);
          border-radius: 999px;
          background: var(--surface);
          color: var(--ink);
          font-size: 13px;
          font-weight: 600;
        }

        .theme-toggle svg { width: 16px; height: 16px; }
        .theme-toggle .i-sun { display: none; }
        .theme-toggle .i-moon { display: inline; }
        [data-theme="dark"] .theme-toggle .i-sun { display: inline; }
        [data-theme="dark"] .theme-toggle .i-moon { display: none; }
        .theme-toggle .label-light { display: inline; }
        .theme-toggle .label-dark { display: none; }
        [data-theme="dark"] .theme-toggle .label-light { display: none; }
        [data-theme="dark"] .theme-toggle .label-dark { display: inline; }

        h1.ds-name {
          margin: 6px 0 0;
          font-size: clamp(40px, 6vw, 64px);
          line-height: 1.02;
          letter-spacing: -0.025em;
          font-weight: 800;
        }

        .ds-summary {
          max-width: 660px;
          margin: 18px 0 0;
          color: var(--muted);
          font-size: 19px;
          line-height: 1.5;
        }

        .ds-meta {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
          margin-top: 22px;
        }

        .pill {
          display: inline-flex;
          align-items: center;
          height: 30px;
          padding: 0 12px;
          border: 1px solid var(--line);
          border-radius: 999px;
          background: var(--surface);
          color: var(--muted);
          font-size: 12.5px;
          font-weight: 600;
          letter-spacing: 0.01em;
        }

        .rule { height: 1px; margin: 38px 0 0; background: var(--line); }

        /* ---- Sections ---- */
        .sec { padding: 56px 0 8px; }

        .sec-head {
          display: flex;
          align-items: baseline;
          gap: 14px;
          margin-bottom: 26px;
        }

        .sec-num {
          font-family: var(--mono);
          font-size: 13px;
          font-weight: 600;
          color: var(--accent);
        }

        .sec-title {
          margin: 0;
          font-size: 13px;
          font-weight: 700;
          letter-spacing: 0.16em;
          text-transform: uppercase;
          color: var(--ink);
        }

        .sec-note {
          margin-left: auto;
          color: var(--faint);
          font-size: 12.5px;
          font-family: var(--mono);
        }

        .group + .group { margin-top: 30px; }
        .group-label {
          margin-bottom: 14px;
          color: var(--muted);
          font-size: 13px;
          font-weight: 700;
        }

        /* ---- Colors ---- */
        .swatch-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(156px, 1fr));
          gap: 14px;
        }

        .swatch {
          display: block;
          text-align: left;
          padding: 0;
          overflow: hidden;
          border: 1px solid var(--line);
          border-radius: 14px;
          background: var(--surface);
          transition: transform 140ms ease, box-shadow 140ms ease;
        }

        .swatch:hover { transform: translateY(-2px); box-shadow: var(--shadow-ambient); }
        .swatch.copied { box-shadow: 0 0 0 2px var(--accent); }

        .swatch-tile {
          display: flex;
          align-items: flex-end;
          height: 92px;
          padding: 12px;
          font-size: 22px;
          font-weight: 700;
        }

        .swatch-meta {
          display: flex;
          flex-direction: column;
          gap: 2px;
          padding: 11px 12px 13px;
        }

        .swatch-name { font-size: 14px; font-weight: 600; color: var(--ink); }
        .swatch-value {
          font-family: var(--mono);
          font-size: 12px;
          text-transform: uppercase;
          color: var(--muted);
        }

        /* ---- Typography ---- */
        .type-row { padding: 22px 0; border-top: 1px solid var(--line); }
        .type-row:first-child { border-top: 0; padding-top: 0; }
        .type-sample { color: var(--ink); overflow-wrap: anywhere; }
        .type-meta {
          margin-top: 12px;
          font-family: var(--mono);
          font-size: 12.5px;
          color: var(--muted);
          letter-spacing: 0.01em;
        }

        /* ---- Scales (spacing / radii) ---- */
        .scale-list { display: grid; gap: 14px; }
        .scale-row {
          display: grid;
          grid-template-columns: 56px 1fr 64px;
          align-items: center;
          gap: 16px;
        }
        .scale-name { font-family: var(--mono); font-size: 13px; color: var(--muted); }
        .scale-track {
          height: 18px;
          border-radius: 6px;
          background: var(--surface-2);
          overflow: hidden;
        }
        .scale-bar {
          display: block;
          height: 100%;
          border-radius: 6px;
          background: color-mix(in srgb, var(--accent) 70%, var(--surface));
        }
        .scale-val { font-family: var(--mono); font-size: 13px; color: var(--ink); text-align: right; }

        .radius-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
          gap: 18px;
        }
        .radius-tile {
          height: 96px;
          border: 1.5px solid var(--accent);
          background: color-mix(in srgb, var(--accent) 9%, var(--surface));
        }
        .radius-cap {
          display: flex;
          justify-content: space-between;
          margin-top: 10px;
          font-size: 13px;
          font-weight: 600;
        }
        .radius-cap .muted { color: var(--muted); font-family: var(--mono); font-weight: 500; }

        /* ---- Elevation carousel ---- */
        .carousel { position: relative; margin: 0 -8px; }
        .carousel-track {
          display: flex;
          gap: 22px;
          padding: 34px 56px;
          overflow-x: auto;
          scroll-snap-type: x mandatory;
          scrollbar-width: none;
        }
        .carousel-track::-webkit-scrollbar { display: none; }

        .elev-card {
          flex: 0 0 auto;
          width: 230px;
          min-height: 172px;
          display: flex;
          flex-direction: column;
          gap: 6px;
          padding: 20px;
          border-radius: 18px;
          background: var(--surface);
          scroll-snap-align: center;
        }
        .elev-name { font-size: 16px; font-weight: 700; }
        .elev-use { flex: 1; color: var(--muted); font-size: 13.5px; line-height: 1.45; }
        .elev-val {
          align-self: flex-start;
          max-width: 100%;
          padding: 6px 9px;
          border: 0;
          border-radius: 8px;
          background: var(--surface-2);
          color: var(--muted);
          font-family: var(--mono);
          font-size: 11px;
          text-align: left;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .elev-val.copied { color: var(--ink); box-shadow: 0 0 0 2px var(--accent); }

        .carousel-btn {
          position: absolute;
          top: 50%;
          transform: translateY(-50%);
          display: grid;
          place-items: center;
          width: 40px;
          height: 40px;
          border: 1px solid var(--line-strong);
          border-radius: 50%;
          background: var(--surface);
          color: var(--ink);
          box-shadow: var(--shadow-ambient);
        }
        .carousel-btn svg { width: 18px; height: 18px; }
        .carousel-btn.prev { left: 6px; }
        .carousel-btn.next { right: 6px; }

        /* ---- States ---- */
        .state-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(168px, 1fr));
          gap: 14px;
        }
        .state-card {
          min-height: 96px;
          padding: 16px;
          border: 1px solid;
          border-radius: 14px;
        }
        .state-name { font-size: 15px; font-weight: 700; }
        .state-desc { margin-top: 6px; font-size: 13px; line-height: 1.4; opacity: 0.8; }

        /* ---- Icons ---- */
        .icon-grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(98px, 1fr));
          gap: 12px;
        }
        .icon-cell {
          display: flex;
          flex-direction: column;
          align-items: center;
          gap: 12px;
          padding: 20px 10px 14px;
          border: 1px solid var(--line);
          border-radius: 14px;
          background: var(--surface);
          color: var(--ink);
        }
        .icon-cell svg { width: 24px; height: 24px; }
        .icon-name { color: var(--muted); font-size: 12px; }

        /* ---- Components ---- */
        .comp { padding: 26px 0; border-top: 1px solid var(--line); }
        .comp:first-child { border-top: 0; padding-top: 0; }
        .comp-title { margin: 0; font-size: 19px; font-weight: 700; letter-spacing: -0.01em; }
        .comp-sum { margin: 6px 0 0; color: var(--muted); font-size: 14.5px; line-height: 1.45; }
        .comp-body { margin-top: 20px; }

        .demo-rows { display: grid; gap: 20px; }
        .demo-row { display: flex; align-items: center; flex-wrap: wrap; gap: 18px; }
        .demo-name { width: 120px; flex: 0 0 120px; color: var(--muted); font-size: 13px; font-weight: 600; }
        .demo-cells { display: flex; flex-wrap: wrap; gap: 18px; align-items: flex-start; }
        .demo-wrap { display: flex; flex-wrap: wrap; gap: 22px; align-items: flex-start; }
        .demo-cell { display: flex; flex-direction: column; align-items: center; gap: 8px; }
        .demo-cap { color: var(--faint); font-size: 11px; font-family: var(--mono); }

        .demo-btn {
          min-height: 40px;
          padding: 0 18px;
          font-size: 14px;
          font-weight: 600;
          transition: filter 120ms ease;
        }
        .demo-btn:not([disabled]):hover { filter: brightness(0.97); }
        .demo-btn[disabled] { cursor: not-allowed; opacity: 0.85; }

        .demo-badge {
          display: inline-flex;
          align-items: center;
          height: 26px;
          padding: 0 11px;
          font-size: 12.5px;
          font-weight: 600;
        }

        .segmented {
          display: inline-flex;
          padding: 4px;
          gap: 2px;
        }
        .segmented .seg {
          border: 0;
          background: transparent;
          color: var(--seg-fg);
          padding: 7px 16px;
          font-size: 13.5px;
          font-weight: 600;
          border-radius: calc(var(--seg-r) - 4px);
          transition: background 140ms ease, color 140ms ease;
        }
        .segmented .seg.is-selected { background: var(--seg-sel-bg); color: var(--seg-sel-fg); box-shadow: 0 1px 2px rgba(0,0,0,0.12); }

        .field-list { display: grid; gap: 18px; max-width: 420px; }
        .field { display: grid; gap: 7px; }
        .field-label { font-size: 13px; font-weight: 600; color: var(--muted); }
        .demo-field {
          width: 100%;
          padding: 11px 13px;
          font: inherit;
          font-size: 14px;
          color: var(--f-fg);
          background: var(--f-bg);
          border: 1px solid var(--f-bd);
          border-radius: var(--f-r);
          outline: none;
          transition: border-color 140ms ease, box-shadow 140ms ease;
        }
        textarea.demo-field { resize: vertical; min-height: 84px; line-height: 1.5; }
        .demo-field::placeholder { color: var(--faint); }
        .demo-field:focus {
          border-color: var(--f-focus);
          box-shadow: 0 0 0 3px color-mix(in srgb, var(--f-focus) 20%, transparent);
        }

        .switch {
          position: relative;
          width: 46px;
          height: 28px;
          padding: 0;
          border: 0;
          border-radius: 999px;
          background: var(--sw-off);
          transition: background 160ms ease;
        }
        .switch.is-on { background: var(--sw-on); }
        .switch-knob {
          position: absolute;
          top: 3px;
          left: 3px;
          width: 22px;
          height: 22px;
          border-radius: 50%;
          background: #fff;
          box-shadow: 0 1px 3px rgba(0,0,0,0.3);
          transition: transform 160ms ease;
        }
        .switch.is-on .switch-knob { transform: translateX(18px); }

        .checkbox, .radio {
          display: grid;
          place-items: center;
          width: 24px;
          height: 24px;
          padding: 0;
          border: 1.5px solid var(--ck-off);
          background: var(--surface);
          color: #fff;
          transition: background 140ms ease, border-color 140ms ease;
        }
        .checkbox { border-radius: 7px; }
        .radio { border-radius: 50%; }
        .checkbox .check-mark { width: 16px; height: 16px; opacity: 0; transition: opacity 120ms ease; }
        .checkbox.is-on { background: var(--ck-on); border-color: var(--ck-on); }
        .checkbox.is-on .check-mark { opacity: 1; }
        .radio.is-on { border-color: var(--ck-on); }
        .radio-dot { width: 11px; height: 11px; border-radius: 50%; background: var(--ck-on); transform: scale(0); transition: transform 140ms ease; }
        .radio.is-on .radio-dot { transform: scale(1); }

        /* ---- Legacy / pending ---- */
        .legacy-group { padding: 22px 0; border-top: 1px solid var(--line); }
        .legacy-group:first-child { border-top: 0; padding-top: 0; }
        .legacy-title { margin: 0; font-size: 18px; font-weight: 700; }
        .legacy-sum { margin: 6px 0 0; color: var(--muted); font-size: 14.5px; line-height: 1.45; }
        .legacy-items { display: grid; gap: 10px; margin-top: 14px; }
        .legacy-item {
          padding: 14px 16px;
          border: 1px solid var(--line);
          border-radius: 12px;
          background: var(--surface);
        }
        .legacy-item h4 { margin: 0; font-size: 15px; }
        .legacy-item p { margin: 5px 0 0; color: var(--muted); font-size: 13.5px; line-height: 1.4; }

        .pending {
          margin-top: 30px;
          padding: 40px;
          border: 1px dashed var(--line-strong);
          border-radius: 18px;
          background: var(--surface);
          color: var(--muted);
          font-size: 16px;
          line-height: 1.55;
        }
        .pending strong { color: var(--ink); }
        .pending code {
          font-family: var(--mono);
          font-size: 13px;
          padding: 1px 6px;
          border-radius: 6px;
          background: var(--surface-2);
        }

        .foot {
          margin-top: 70px;
          padding-top: 22px;
          border-top: 1px solid var(--line);
          color: var(--faint);
          font-size: 12.5px;
          font-family: var(--mono);
        }

        @media (max-width: 640px) {
          .wrap { width: calc(100vw - 28px); }
          .demo-name { width: 100%; flex-basis: 100%; }
          .scale-row { grid-template-columns: 48px 1fr 56px; gap: 12px; }
        }
      </style>
    </head>
    <body class="is-pending">
      <main class="wrap">
        <div class="topbar">
          <span class="brand"><span class="brand-dot"></span>Design System</span>
          <button id="theme-toggle" class="theme-toggle" type="button" aria-label="Toggle color theme">
            <svg class="i-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path></svg>
            <svg class="i-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path></svg>
            <span class="label-light">Light</span><span class="label-dark">Dark</span>
          </button>
        </div>

        <header>
          <h1 class="ds-name" id="ds-name">\(title)</h1>
          <p class="ds-summary" id="ds-summary"></p>
          <div class="ds-meta" id="ds-meta"></div>
        </header>
        <div class="rule"></div>

        <div id="sections"></div>

        <div class="foot" id="ds-foot">Codex Design System</div>
      </main>

      <script>
        window.__EASEL_FALLBACK__ = { name: "\(fallbackName)", summary: "\(fallbackSummary)" };

        const FALLBACK = window.__EASEL_FALLBACK__;
        const root = document.documentElement;
        const THEME_KEY = "easel-ds-theme";

        initTheme();
        document.addEventListener("click", onClick);
        loadCatalog();

        function initTheme() {
          let t = localStorage.getItem(THEME_KEY);
          if (t !== "light" && t !== "dark") {
            t = (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) ? "dark" : "light";
          }
          root.setAttribute("data-theme", t);
        }

        function toggleTheme() {
          const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
          localStorage.setItem(THEME_KEY, next);
          root.setAttribute("data-theme", next);
        }

        async function loadCatalog() {
          try {
            const res = await fetch(".easel/catalog.json", { cache: "no-store" });
            if (!res.ok) { throw new Error("Catalog not found"); }
            const data = await res.json();
            render(data);
          } catch (err) {
            renderPending();
            if (err) { console.info(String(err.message || err)); }
          }
        }

        function render(data) {
          const name = text(data.name) || FALLBACK.name;
          const summary = text(data.summary) || FALLBACK.summary;
          document.getElementById("ds-name").textContent = name;
          document.getElementById("ds-summary").textContent = summary;
          document.title = name + " — Design System";

          if (hasTokenContent(data)) {
            renderTokens(data);
          } else if (hasLegacyContent(data)) {
            renderLegacy(data);
            renderMeta(data, null);
          } else {
            renderPending();
            return;
          }
          document.body.classList.remove("is-pending");
        }

        function renderTokens(data) {
          const accent = pickAccent(data.colors);
          if (accent) { root.style.setProperty("--accent", accent); }

          const blocks = [];
          let n = 0;
          const add = (titleText, note, body) => {
            if (!body) { return; }
            n += 1;
            const num = String(n).padStart(2, "0");
            blocks.push(`
              <section class="sec">
                <div class="sec-head">
                  <span class="sec-num">${num}</span>
                  <h2 class="sec-title">${escapeHTML(titleText)}</h2>
                  ${note ? `<span class="sec-note">${escapeHTML(note)}</span>` : ""}
                </div>
                <div class="sec-body">${body}</div>
              </section>
            `);
          };

          const typography = data.typography || {};
          add("Colors", count(data.colors, "token"), renderColors(data.colors || []));
          add("Typography", count(typography.styles, "style"), renderType(typography));
          add("Spacing", count(data.spacing, "step"), renderScale(data.spacing || []));
          add("Radius", count(data.radii, "step"), renderRadii(data.radii || []));
          add("Elevation", count(data.elevation, "level"), renderElevation(data.elevation || []));
          add("States", count(data.states, "state"), renderStates(data.states || []));
          add("Iconography", count(data.icons, "icon"), renderIcons(data.icons || []));
          add("Components", count(data.components, "set"), renderComponents(data.components || []));

          document.getElementById("sections").innerHTML = blocks.join("") || pendingHTML();
          renderMeta(data, totalTokens(data));
        }

        function renderMeta(data, tokenCount) {
          const meta = [];
          if (typeof tokenCount === "number") {
            meta.push(`${tokenCount} ${tokenCount === 1 ? "token" : "tokens"}`);
          }
          if (data.generatedAt) {
            const when = formatDate(data.generatedAt);
            if (when) { meta.push(when); }
          }
          document.getElementById("ds-meta").innerHTML = meta.map(m => `<span class="pill">${escapeHTML(m)}</span>`).join("");
          const version = data.schemaVersion ? `schema v${data.schemaVersion}` : "schema v3";
          document.getElementById("ds-foot").textContent = `Codex Design System · ${version}`;
        }

        /* ---------- Section renderers ---------- */

        function renderColors(colors) {
          if (!colors.length) { return ""; }
          const groups = {};
          const order = [];
          colors.forEach(c => {
            const g = text(c.group) || "Palette";
            if (!groups[g]) { groups[g] = []; order.push(g); }
            groups[g].push(c);
          });
          return order.map(g => `
            <div class="group">
              <div class="group-label">${escapeHTML(g)}</div>
              <div class="swatch-grid">${groups[g].map(swatch).join("")}</div>
            </div>
          `).join("");
        }

        function swatch(c) {
          const value = text(c.value);
          const on = text(c.onColor) || readableOn(value);
          return `
            <button class="swatch" type="button" data-copy="${escapeAttr(value)}" title="Copy ${escapeAttr(value)}">
              <span class="swatch-tile" style="${escapeAttr(`background:${value};color:${on}`)}">Aa</span>
              <span class="swatch-meta">
                <span class="swatch-name">${escapeHTML(c.name)}</span>
                <span class="swatch-value">${escapeHTML(value)}</span>
              </span>
            </button>
          `;
        }

        function renderType(typography) {
          const styles = (typography && typography.styles) || [];
          if (!styles.length) { return ""; }
          const fontByRole = {};
          (typography.fonts || []).forEach(f => {
            if (f.role) { fontByRole[String(f.role).toLowerCase()] = f; }
            if (f.link) { addFontLink(f.link); }
          });
          return styles.map(s => {
            const f = s.fontRole ? fontByRole[String(s.fontRole).toLowerCase()] : null;
            const stack = (f && f.stack) ? f.stack : (f && f.family) ? f.family : "var(--ui)";
            const size = s.size ? s.size : 24;
            const style = `font-family:${stack};font-size:${size}px;font-weight:${s.weight || 400};line-height:${s.lineHeight || 1.2};letter-spacing:${s.letterSpacing || "normal"}`;
            const sample = text(s.sample) || "The quick brown fox jumps over the lazy dog";
            const meta = [
              s.name,
              s.size ? `${num(s.size)}px` : null,
              s.weight ? String(s.weight) : null,
              s.lineHeight ? `LH ${num(s.lineHeight)}` : null,
              f ? f.family : null,
              s.usage
            ].filter(Boolean).join("  ·  ");
            return `
              <div class="type-row">
                <div class="type-sample" style="${escapeAttr(style)}">${escapeHTML(sample)}</div>
                <div class="type-meta">${escapeHTML(meta)}</div>
              </div>
            `;
          }).join("");
        }

        function renderScale(tokens) {
          if (!tokens.length) { return ""; }
          const max = Math.max.apply(null, tokens.map(t => Number(t.value) || 0).concat([1]));
          return `<div class="scale-list">${tokens.map(t => {
            const value = Number(t.value) || 0;
            const w = Math.max(2, Math.round((value / max) * 100));
            return `
              <div class="scale-row">
                <span class="scale-name">${escapeHTML(t.name)}</span>
                <span class="scale-track"><span class="scale-bar" style="width:${w}%"></span></span>
                <span class="scale-val">${num(value)}px</span>
              </div>
            `;
          }).join("")}</div>`;
        }

        function renderRadii(tokens) {
          if (!tokens.length) { return ""; }
          return `<div class="radius-grid">${tokens.map(t => `
            <div class="radius-item">
              <div class="radius-tile" style="border-radius:${num(Number(t.value) || 0)}px"></div>
              <div class="radius-cap"><span>${escapeHTML(t.name)}</span><span class="muted">${num(Number(t.value) || 0)}px</span></div>
            </div>
          `).join("")}</div>`;
        }

        function renderElevation(levels) {
          if (!levels.length) { return ""; }
          const cards = levels.map(l => `
            <div class="elev-card" style="box-shadow:${escapeAttr(text(l.shadow))}">
              <div class="elev-name">${escapeHTML(l.name)}</div>
              <div class="elev-use">${escapeHTML(text(l.usage))}</div>
              <button class="elev-val" type="button" data-copy="${escapeAttr(text(l.shadow))}" title="Copy shadow">${escapeHTML(text(l.shadow))}</button>
            </div>
          `).join("");
          return `
            <div class="carousel">
              <button class="carousel-btn prev" type="button" aria-label="Previous">${chevron(false)}</button>
              <div class="carousel-track">${cards}</div>
              <button class="carousel-btn next" type="button" aria-label="Next">${chevron(true)}</button>
            </div>
          `;
        }

        function renderStates(states) {
          if (!states.length) { return ""; }
          return `<div class="state-grid">${states.map(s => {
            const bg = text(s.background) || "var(--surface)";
            const fg = text(s.foreground) || "var(--ink)";
            const bd = text(s.border) || "var(--line)";
            return `
              <div class="state-card" style="${escapeAttr(`background:${bg};color:${fg};border-color:${bd}`)}">
                <div class="state-name">${escapeHTML(s.name)}</div>
                <div class="state-desc">${escapeHTML(text(s.description))}</div>
              </div>
            `;
          }).join("")}</div>`;
        }

        function renderIcons(icons) {
          if (!icons.length) { return ""; }
          return `<div class="icon-grid">${icons.map(i => `
            <div class="icon-cell"><span class="icon-svg">${svgMarkup(i.svg)}</span><span class="icon-name">${escapeHTML(i.name)}</span></div>
          `).join("")}</div>`;
        }

        function renderComponents(components) {
          if (!components.length) { return ""; }
          return components.map(c => {
            const body = renderComponent(c);
            if (!body) { return ""; }
            return `
              <div class="comp">
                <div class="comp-head">
                  <h3 class="comp-title">${escapeHTML(c.name)}</h3>
                  ${c.summary ? `<p class="comp-sum">${escapeHTML(c.summary)}</p>` : ""}
                </div>
                <div class="comp-body">${body}</div>
              </div>
            `;
          }).join("");
        }

        function renderComponent(c) {
          const variants = c.variants || [];
          if (!variants.length) { return ""; }
          switch (String(c.kind || "").toLowerCase()) {
            case "badge": return renderBadges(variants);
            case "segmented": return renderSegmented(variants);
            case "textfield": return renderFields(variants, false);
            case "input": return renderFields(variants, false);
            case "textarea": return renderFields(variants, true);
            case "toggle": case "switch": return renderToggles(variants);
            case "checkbox": return renderChecks(variants, "checkbox");
            case "radio": return renderChecks(variants, "radio");
            default: return renderButtons(variants);
          }
        }

        /* ---------- Component renderers ---------- */

        function btnStyle(base, ov) {
          ov = ov || {};
          const bg = ov.background || base.background || "var(--ink)";
          const fg = ov.foreground || base.foreground || "var(--page)";
          const bd = (ov.border !== undefined ? ov.border : base.border) || "transparent";
          const sh = ov.shadow || base.shadow;
          const r = base.radius !== undefined ? base.radius : 8;
          let s = `background:${bg};color:${fg};border:1px solid ${bd};border-radius:${num(r)}px`;
          if (sh) { s += `;box-shadow:${sh}`; }
          return s;
        }

        function renderButtons(variants) {
          return `<div class="demo-rows">${variants.map(v => {
            const states = v.states || {};
            const cells = [demoBtn(v, null, "Default", false)];
            ["hover", "active", "focus", "disabled"].forEach(k => {
              if (states[k]) { cells.push(demoBtn(v, states[k], cap(k), k === "disabled")); }
            });
            return `<div class="demo-row"><span class="demo-name">${escapeHTML(v.name)}</span><div class="demo-cells">${cells.join("")}</div></div>`;
          }).join("")}</div>`;
        }

        function demoBtn(v, ov, capt, disabled) {
          const label = text(v.label) || v.name;
          return `<div class="demo-cell"><button class="demo-btn" type="button" ${disabled ? "disabled" : ""} style="${escapeAttr(btnStyle(v, ov))}">${escapeHTML(label)}</button><span class="demo-cap">${escapeHTML(capt)}</span></div>`;
        }

        function renderBadges(variants) {
          return `<div class="demo-wrap">${variants.map(v => {
            const bg = v.background || "var(--surface-2)";
            const fg = v.foreground || "var(--ink)";
            const bd = v.border || "transparent";
            const r = v.radius !== undefined ? v.radius : 999;
            const s = `background:${bg};color:${fg};border:1px solid ${bd};border-radius:${num(r)}px`;
            return `<div class="demo-cell"><span class="demo-badge" style="${escapeAttr(s)}">${escapeHTML(text(v.label) || v.name)}</span><span class="demo-cap">${escapeHTML(v.name)}</span></div>`;
          }).join("")}</div>`;
        }

        function renderSegmented(variants) {
          return `<div class="demo-rows">${variants.map(v => {
            const opts = v.options || [];
            const sel = v.selectedIndex || 0;
            const vars = `--seg-fg:${v.foreground || "var(--muted)"};--seg-sel-bg:${v.selectedBackground || "var(--surface)"};--seg-sel-fg:${v.selectedForeground || "var(--ink)"};--seg-r:${num(v.radius !== undefined ? v.radius : 10)}px;background:${v.background || "var(--surface-2)"};border-radius:${num(v.radius !== undefined ? v.radius : 10)}px`;
            const segs = opts.map((o, i) => `<button type="button" class="seg${i === sel ? " is-selected" : ""}">${escapeHTML(o)}</button>`).join("");
            return `<div class="demo-row"><span class="demo-name">${escapeHTML(v.name)}</span><div class="segmented" style="${escapeAttr(vars)}">${segs}</div></div>`;
          }).join("")}</div>`;
        }

        function renderFields(variants, isArea) {
          return `<div class="field-list">${variants.map(v => {
            const vars = `--f-bg:${v.background || "var(--surface)"};--f-fg:${v.foreground || "var(--ink)"};--f-bd:${v.border || "var(--line-strong)"};--f-focus:${v.focusBorder || "var(--accent)"};--f-r:${num(v.radius !== undefined ? v.radius : 8)}px`;
            const ph = escapeAttr(text(v.placeholder));
            const ctrl = isArea
              ? `<textarea class="demo-field" rows="3" placeholder="${ph}" style="${escapeAttr(vars)}"></textarea>`
              : `<input class="demo-field" type="text" placeholder="${ph}" style="${escapeAttr(vars)}">`;
            return `<label class="field"><span class="field-label">${escapeHTML(text(v.label) || v.name)}</span>${ctrl}</label>`;
          }).join("")}</div>`;
        }

        function renderToggles(variants) {
          return `<div class="demo-wrap">${variants.map(v => {
            const checked = v.checked === true;
            const vars = `--sw-on:${v.onColor || "var(--accent)"};--sw-off:${v.offColor || "var(--line-strong)"}`;
            return `<div class="demo-cell"><button type="button" class="switch${checked ? " is-on" : ""}" style="${escapeAttr(vars)}" aria-pressed="${checked}"><span class="switch-knob"></span></button><span class="demo-cap">${escapeHTML(v.name)}</span></div>`;
          }).join("")}</div>`;
        }

        function renderChecks(variants, kind) {
          return `<div class="demo-wrap">${variants.map(v => {
            const checked = v.checked === true;
            const vars = `--ck-on:${v.onColor || "var(--accent)"};--ck-off:${v.offColor || "var(--line-strong)"}`;
            const inner = kind === "radio"
              ? `<span class="radio-dot"></span>`
              : `<svg viewBox="0 0 24 24" class="check-mark" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 13l4 4 10-10"></path></svg>`;
            return `<div class="demo-cell"><button type="button" class="${kind}${checked ? " is-on" : ""}" style="${escapeAttr(vars)}" aria-pressed="${checked}">${inner}</button><span class="demo-cap">${escapeHTML(text(v.label) || v.name)}</span></div>`;
          }).join("")}</div>`;
        }

        /* ---------- Legacy + pending ---------- */

        function renderLegacy(data) {
          const sections = (data.sections && data.sections.length)
            ? data.sections
            : [{ title: "Components", groups: data.componentGroups || [] }];
          const html = sections.map(section => {
            const groups = (section.groups || []).map(g => `
              <div class="legacy-group">
                <h3 class="legacy-title">${escapeHTML(g.title)}</h3>
                ${g.summary ? `<p class="legacy-sum">${escapeHTML(g.summary)}</p>` : ""}
                ${(g.items && g.items.length) ? `<div class="legacy-items">${g.items.map(it => `
                  <div class="legacy-item"><h4>${escapeHTML(it.title)}</h4>${it.summary ? `<p>${escapeHTML(it.summary)}</p>` : ""}</div>
                `).join("")}</div>` : ""}
              </div>
            `).join("");
            return `
              <section class="sec">
                <div class="sec-head"><h2 class="sec-title">${escapeHTML(section.title || "Catalog")}</h2></div>
                <div class="sec-body">${groups}</div>
              </section>
            `;
          }).join("");
          document.getElementById("sections").innerHTML = html;
        }

        function renderPending() {
          document.getElementById("ds-name").textContent = FALLBACK.name;
          document.getElementById("ds-summary").textContent = FALLBACK.summary || "The catalog will render here once it is generated.";
          document.getElementById("ds-meta").innerHTML = `<span class="pill">Pending</span>`;
          document.getElementById("sections").innerHTML = pendingHTML();
          document.body.classList.remove("is-pending");
        }

        function pendingHTML() {
          return `
            <div class="pending">
              <strong>Catalog pending.</strong><br>
              Generate <code>.easel/catalog.json</code> with design tokens and this canvas will render the system — colors, type, spacing, elevation, states, icons, and components.
            </div>
          `;
        }

        /* ---------- Interactions ---------- */

        function onClick(event) {
          const tt = event.target.closest("#theme-toggle");
          if (tt) { toggleTheme(); return; }

          const seg = event.target.closest(".segmented .seg");
          if (seg) {
            const group = seg.parentElement;
            group.querySelectorAll(".seg").forEach(s => s.classList.remove("is-selected"));
            seg.classList.add("is-selected");
            return;
          }

          const sw = event.target.closest(".switch, .checkbox, .radio");
          if (sw) {
            sw.classList.toggle("is-on");
            sw.setAttribute("aria-pressed", sw.classList.contains("is-on") ? "true" : "false");
            return;
          }

          const carBtn = event.target.closest(".carousel-btn");
          if (carBtn) {
            const track = carBtn.parentElement.querySelector(".carousel-track");
            if (track) {
              const dir = carBtn.classList.contains("next") ? 1 : -1;
              track.scrollBy({ left: dir * track.clientWidth * 0.7, behavior: "smooth" });
            }
            return;
          }

          const copy = event.target.closest("[data-copy]");
          if (copy && navigator.clipboard) {
            navigator.clipboard.writeText(copy.getAttribute("data-copy")).then(() => {
              copy.classList.add("copied");
              setTimeout(() => copy.classList.remove("copied"), 900);
            }).catch(() => {});
          }
        }

        /* ---------- Helpers ---------- */

        function hasTokenContent(data) {
          return nonEmpty(data.colors)
            || (data.typography && nonEmpty(data.typography.styles))
            || nonEmpty(data.spacing)
            || nonEmpty(data.radii)
            || nonEmpty(data.elevation)
            || nonEmpty(data.states)
            || nonEmpty(data.icons)
            || nonEmpty(data.components);
        }

        function hasLegacyContent(data) {
          return nonEmpty(data.sections) || nonEmpty(data.componentGroups);
        }

        function totalTokens(data) {
          const typo = (data.typography && data.typography.styles) ? data.typography.styles.length : 0;
          return len(data.colors) + typo + len(data.spacing) + len(data.radii)
            + len(data.elevation) + len(data.states) + len(data.icons) + len(data.components);
        }

        function pickAccent(colors) {
          if (!nonEmpty(colors)) { return null; }
          const brand = colors.find(c => String(c.group || "").toLowerCase().indexOf("brand") >= 0);
          const semantic = colors.find(c => String(c.group || "").toLowerCase().indexOf("accent") >= 0);
          const chosen = brand || semantic || colors[0];
          return text(chosen.value) || null;
        }

        function addFontLink(href) {
          href = text(href);
          if (!href) { return; }
          if (document.querySelector(`link[data-font="${cssEscape(href)}"]`)) { return; }
          const link = document.createElement("link");
          link.rel = "stylesheet";
          link.href = href;
          link.setAttribute("data-font", href);
          document.head.appendChild(link);
        }

        function svgMarkup(svg) {
          const s = text(svg);
          if (!s) { return ""; }
          if (/^<svg/i.test(s)) { return s; }
          return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${s}</svg>`;
        }

        function chevron(right) {
          const d = right ? "M9 6l6 6-6 6" : "M15 6l-6 6 6 6";
          return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"></path></svg>`;
        }

        function readableOn(color) {
          const rgb = parseHex(color);
          if (!rgb) { return "#ffffff"; }
          const L = 0.2126 * lin(rgb.r) + 0.7152 * lin(rgb.g) + 0.0722 * lin(rgb.b);
          return L > 0.45 ? "#15171c" : "#ffffff";
        }

        function lin(c) {
          c = c / 255;
          return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        }

        function parseHex(value) {
          let s = text(value).replace("#", "");
          if (s.length === 3) { s = s.split("").map(x => x + x).join(""); }
          if (s.length !== 6) { return null; }
          const n = parseInt(s, 16);
          if (isNaN(n)) { return null; }
          return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
        }

        function count(arr, word) {
          const c = len(arr);
          if (!c) { return ""; }
          return c + " " + word + (c === 1 ? "" : "s");
        }

        function cap(value) { return value.charAt(0).toUpperCase() + value.slice(1); }
        function len(arr) { return Array.isArray(arr) ? arr.length : 0; }
        function nonEmpty(arr) { return Array.isArray(arr) && arr.length > 0; }

        function num(value) {
          const n = Number(value);
          if (!isFinite(n)) { return "0"; }
          return Number.isInteger(n) ? String(n) : String(Math.round(n * 100) / 100);
        }

        function formatDate(value) {
          const d = new Date(value);
          if (isNaN(d.getTime())) { return ""; }
          try {
            return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
          } catch (e) {
            return "";
          }
        }

        function text(value) { return typeof value === "string" ? value.trim() : (value == null ? "" : String(value)); }

        function escapeHTML(value) {
          return text(value)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#39;");
        }

        function escapeAttr(value) { return escapeHTML(value); }
        function cssEscape(value) { return text(value).replace(/"/g, ""); }
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

  private static func scriptString(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "</", with: "<\\/")
  }
}
