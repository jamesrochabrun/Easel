//
//  SlideDeckPreviewScript.swift
//  EaselSlides
//

import Foundation

public enum SlideDeckFirstSlidePreparationScript {
  public static var script: String {
    SlideDeckPreviewScript.installAndSelectScript(selectedIndex: 0, fastForwardMotion: true)
  }
}

enum SlideDeckPreviewScript {
  static func installAndSelectScript(
    selectedIndex: Int,
    fastForwardMotion: Bool = false
  ) -> String {
    """
    (() => {
      const runtimeName = "__easelSlideDeckRuntime";
      const slideAttribute = "data-easel-runtime-slide";
      const selectedAttribute = "data-easel-runtime-selected";
      const deckSelector = "[data-easel-deck]";
      const fastForwardMotion = \(fastForwardMotion ? "true" : "false");

      function slideElements() {
        const selectors = ["[data-easel-slide]", ".easel-slide", ".slide", "section"];
        for (const selector of selectors) {
          const matches = Array.from(document.querySelectorAll(selector))
            .filter((element) => element instanceof HTMLElement);
          if (matches.length > 0) {
            return matches;
          }
        }
        return document.body instanceof HTMLElement ? [document.body] : [];
      }

      function textTitle(element, index) {
        const explicitTitle = element.getAttribute("data-title") || element.getAttribute("aria-label");
        if (explicitTitle && explicitTitle.trim().length > 0) {
          return explicitTitle.trim();
        }

        const heading = element.querySelector("h1, h2, h3");
        if (heading && heading.textContent && heading.textContent.trim().length > 0) {
          return heading.textContent.trim();
        }

        return `Slide ${index + 1}`;
      }

      function ensureStyle() {
        let style = document.getElementById("easel-slide-preview-runtime-style");
        if (!style) {
          style = document.createElement("style");
          style.id = "easel-slide-preview-runtime-style";
          document.head.appendChild(style);
        }

        style.textContent = `
          html, body {
            width: 100% !important;
            height: 100% !important;
            margin: 0 !important;
            overflow: hidden !important;
            background: #ffffff !important;
          }

          body.__easel-slide-preview-active {
            min-height: 100% !important;
            display: block !important;
            padding: 0 !important;
          }

          ${deckSelector} {
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

          [${slideAttribute}] {
            opacity: 0 !important;
            pointer-events: none !important;
            width: 100% !important;
            height: 100% !important;
            overflow: hidden !important;
            border: 0 !important;
            border-radius: 0 !important;
            box-shadow: none !important;
            clip-path: inset(0) !important;
            contain: paint !important;
          }

          [${slideAttribute}][${selectedAttribute}="true"] {
            opacity: 1 !important;
            pointer-events: auto !important;
          }

          body.__easel-slide-preview-fast-motion *,
          body.__easel-slide-preview-fast-motion *::before,
          body.__easel-slide-preview-fast-motion *::after {
            animation-delay: 0s !important;
            animation-duration: 1ms !important;
            animation-iteration-count: 1 !important;
            transition-delay: 0s !important;
            transition-duration: 1ms !important;
          }
        `;

        document.body?.classList.add("__easel-slide-preview-active");
        document.body?.classList.toggle("__easel-slide-preview-fast-motion", fastForwardMotion);
      }

      function rememberOriginalDisplay(element) {
        if (!element.dataset.easelRuntimeDisplay) {
          const display = window.getComputedStyle(element).display;
          element.dataset.easelRuntimeDisplay = display && display !== "none" ? display : "block";
        }
      }

      function clearStaleRuntimeAttributes(activeSlides) {
        const activeSet = new Set(activeSlides);
        document.querySelectorAll(`[${slideAttribute}]`).forEach((element) => {
          if (!activeSet.has(element)) {
            element.removeAttribute(slideAttribute);
            element.removeAttribute(selectedAttribute);
            element.removeAttribute("data-active");
            element.style.removeProperty("display");
            element.style.removeProperty("position");
            element.style.removeProperty("inset");
            element.style.removeProperty("width");
            element.style.removeProperty("height");
            element.style.removeProperty("margin");
            element.style.removeProperty("box-sizing");
            element.style.removeProperty("overflow");
            element.style.removeProperty("border");
            element.style.removeProperty("border-radius");
            element.style.removeProperty("box-shadow");
            element.style.removeProperty("clip-path");
            element.style.removeProperty("contain");
          }
        });
      }

      function metadataFor(slides) {
        return slides.map((element, index) => ({
          index,
          title: textTitle(element, index)
        }));
      }

      function applySelection(index) {
        ensureStyle();
        const slides = slideElements();
        clearStaleRuntimeAttributes(slides);

        if (slides.length === 0) {
          return [];
        }

        const selectedIndex = Math.max(0, Math.min(Number(index) || 0, slides.length - 1));
        window[runtimeName].selectedIndex = selectedIndex;

        slides.forEach((element, slideIndex) => {
          rememberOriginalDisplay(element);
          element.setAttribute(slideAttribute, "");

          if (slideIndex === selectedIndex) {
            element.setAttribute(selectedAttribute, "true");
            // Drive the deck's own active-slide signal too. Generated decks gate
            // their entrance reveals on `[data-active="true"]` (e.g. content that
            // starts at opacity:0 and only becomes visible through a keyframe).
            // Without this the selected slide section is shown but its content
            // stays hidden, rendering a blank slide with only decorative layers.
            element.setAttribute("data-active", "true");
            element.style.setProperty("display", element.dataset.easelRuntimeDisplay || "block", "important");
            element.style.setProperty("position", "fixed", "important");
            element.style.setProperty("inset", "0", "important");
            element.style.setProperty("width", "100vw", "important");
            element.style.setProperty("height", "100vh", "important");
            element.style.setProperty("margin", "0", "important");
            element.style.setProperty("box-sizing", "border-box", "important");
            element.style.setProperty("overflow", "hidden", "important");
            element.style.setProperty("border", "0", "important");
            element.style.setProperty("border-radius", "0", "important");
            element.style.setProperty("box-shadow", "none", "important");
            element.style.setProperty("clip-path", "inset(0)", "important");
            element.style.setProperty("contain", "paint", "important");
          } else {
            element.removeAttribute(selectedAttribute);
            element.removeAttribute("data-active");
            element.style.setProperty("display", "none", "important");
          }
        });

        return metadataFor(slides);
      }

      window[runtimeName] = window[runtimeName] || {};
      window[runtimeName].discover = () => applySelection(window[runtimeName].selectedIndex || 0);
      window[runtimeName].select = (index) => applySelection(index);

      return window[runtimeName].select(\(selectedIndex));
    })()
    """
  }

  static func selectScript(index: Int) -> String {
    """
    (() => {
      if (!window.__easelSlideDeckRuntime) {
        return [];
      }
      return window.__easelSlideDeckRuntime.select(\(index));
    })()
    """
  }
}
