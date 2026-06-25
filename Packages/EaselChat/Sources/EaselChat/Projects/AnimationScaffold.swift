//
//  AnimationScaffold.swift
//  EaselChat
//

import Foundation

enum AnimationScaffold {
  static let starterResourcePath = "resources/animations.jsx"
  static let vendorDirectoryPath = "resources/vendor"
  static let vendorFileNames = [
    "react.production.min.js",
    "react-dom.production.min.js",
    "babel.min.js",
  ]

  static let readmeGuidance = """
  Build this as an animated video or motion design piece rendered in `index.html`. Use a fixed export-ready stage, usually 1280x720 for 16:9. The starter timeline engine is bundled at `resources/animations.jsx`, and the React/Babel runtime is vendored at `resources/vendor/` so previews work without a network request.
  """

  static let authoringGuidance = """
  Create an animated video or motion design piece rendered as an HTML page. Build a timeline-based animation with smooth transitions. Design frame-by-frame sequences with playback controls (play/pause, scrubber). Focus on visual storytelling that uses the selected design system when one is provided; otherwise default to a simple, plain visual language with great taste. Export-ready at a fixed aspect ratio (16:9 or 9:16). If you need to know the position of an element (e.g. to move a cursor or character between elements) use refs to grab the position.
  START by calling copy_starter_component with kind: "animations.jsx" -- it gives you a ready-made timeline engine that exports to window: Stage, Sprite, PlaybackBar, TextSprite, ImageSprite, RectSprite, useTime, useTimeline, useSprite, Easing, interpolate, animate, and clamp. If that tool is not available, use the already bundled starter at `resources/animations.jsx`.
  How the engine works:

  <Stage width height duration background> is the root. It auto-scales to the viewport and provides the full playback UI -- scrubber, play/pause, left/right seek (hold shift for 1s steps), space to toggle, 0/Home to reset -- and persists the playhead to localStorage. Wrap your scenes inside it.
  Any child can call useTime() to read the current playhead in seconds, or useTimeline() for { time, duration, playing, setTime, setPlaying }.
  <Sprite start end> gates its children to a time window and supplies { localTime, progress, duration, visible } either via render-prop ({({progress}) => ...}) or the useSprite() hook. Pass keepMounted to keep it mounted outside its window.
  Use Easing (linear, quad/cubic/quart/expo/sine, plus back and elastic overshoots), interpolate(input, output, ease) for multi-keyframe tweens, and animate({from, to, start, end, ease}) for single-segment tweens. clamp(v, min, max) is available too.
  TextSprite, ImageSprite (with optional Ken Burns + striped placeholder), and RectSprite are ready-made primitives with built-in entry/exit animation.

  Compose YOUR scenes as nested <Sprite> blocks keyed to start/end times, drive transform/opacity off localTime/progress, and keep all timing data-driven so the scrubber stays in sync. Load the bundled local React + Babel files from `resources/vendor/` in the HTML host page.
  Deliver a single self-contained HTML/JSX file: scenes sequenced on the timeline, smoothly eased transitions between them, styling that follows the selected design system when available or a simple plain default when not, and a fixed 16:9 stage (e.g. 1280x720).
  """

  static func indexHTML(
    title rawTitle: String,
    designSystemDisplayName rawDesignSystemDisplayName: String
  ) -> String {
    let title = escapedHTML(rawTitle)
    let titleLiteral = javaScriptStringLiteral(rawTitle)
    let designSystemDisplayNameLiteral = javaScriptStringLiteral(rawDesignSystemDisplayName)

    return #"""
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\#(title)</title>
      <style>
        :root {
          color-scheme: light;
          --motion-bg: #f8fafc;
          --motion-ink: #111827;
          --motion-muted: #64748b;
          --motion-accent: #2563eb;
        }

        * {
          box-sizing: border-box;
        }

        html,
        body,
        #root {
          width: 100%;
          height: 100%;
          margin: 0;
        }

        body {
          overflow: hidden;
          background: #0a0a0a;
        }

      </style>
      <script src="./resources/vendor/react.production.min.js"></script>
      <script src="./resources/vendor/react-dom.production.min.js"></script>
      <script src="./resources/vendor/babel.min.js"></script>
      <script>
        Babel.registerPreset('react-classic', {
          presets: [[Babel.availablePresets['react'], { runtime: 'classic' }]],
        });
      </script>
      <script type="text/babel" data-presets="react-classic" src="./resources/animations.jsx"></script>
    </head>
    <body>
      <div id="root"></div>

      <script>
        window.addEventListener('load', function () {
          setTimeout(function () {
            var root = document.getElementById('root');
            if (!root || root.childElementCount > 0) return;

            var missing = [];
            if (!window.React) missing.push('React');
            if (!window.ReactDOM) missing.push('ReactDOM');
            if (!window.Babel) missing.push('Babel');
            if (window.Babel && !window.Stage) missing.push('engine (resources/animations.jsx)');

            root.innerHTML =
              '<div style="position:absolute;inset:0;display:flex;flex-direction:column;gap:10px;' +
              'align-items:center;justify-content:center;text-align:center;padding:28px;color:#f8fafc;' +
              'font:14px/1.6 Inter,system-ui,sans-serif;background:#0a0a0a">' +
              '<div style="font-size:16px;font-weight:600">Preview failed to mount</div>' +
              '<div style="opacity:.65">Missing: ' + (missing.join(', ') || 'unknown - check console') + '</div>' +
              '</div>';
          }, 2000);
        });
      </script>

      <script type="text/babel" data-presets="react-classic">
        (function () {
        let Stage;
        let Sprite;
        let TextSprite;
        let RectSprite;
        let useSprite;
        let Easing;
        let interpolate;
        let animate;
        let clamp;

        const palette = {
          bg: '#f8fafc',
          ink: '#111827',
          muted: '#64748b',
          accent: '#2563eb',
          line: '#d7dde6',
          panel: '#ffffff',
        };
        const projectTitle = \#(titleLiteral);
        const designSystemName = \#(designSystemDisplayNameLiteral);

        function MotionBoard() {
          const { progress } = useSprite();
          const markerX = interpolate([0, 0.48, 1], [24, 178, 330], [Easing.easeOutCubic, Easing.easeInOutSine])(progress);
          const markerY = interpolate([0, 0.48, 1], [214, 96, 158], Easing.easeInOutSine)(progress);
          const scale = animate({ from: 0.96, to: 1, start: 0, end: 0.35, ease: Easing.easeOutCubic })(progress);

          return (
            <div style={{
              position: 'absolute',
              left: 744,
              top: 128,
              width: 392,
              height: 304,
              transform: `scale(${scale})`,
              opacity: clamp(progress * 1.4, 0, 1),
            }}>
              <div style={{
                position: 'absolute',
                inset: 0,
                border: `1px solid ${palette.line}`,
                borderRadius: 18,
                background: palette.panel,
                boxShadow: '0 24px 70px rgba(15, 23, 42, 0.10)',
              }} />
              <div style={{
                position: 'absolute',
                left: 24,
                right: 24,
                top: 24,
                bottom: 24,
                borderRadius: 12,
                background: `linear-gradient(${palette.line} 1px, transparent 1px), linear-gradient(90deg, ${palette.line} 1px, transparent 1px)`,
                backgroundSize: '40px 40px',
                opacity: 0.72,
              }} />
              <div style={{
                position: 'absolute',
                left: 24,
                top: 238,
                width: 344,
                height: 3,
                background: palette.line,
                borderRadius: 2,
              }} />
              <div style={{
                position: 'absolute',
                left: 24,
                top: 238,
                width: markerX,
                height: 3,
                background: palette.accent,
                borderRadius: 2,
              }} />
              <div style={{
                position: 'absolute',
                left: markerX,
                top: markerY,
                width: 42,
                height: 42,
                borderRadius: 10,
                background: palette.accent,
                boxShadow: '0 14px 30px rgba(37, 99, 235, 0.22)',
              }} />
            </div>
          );
        }

        function TimelineRule() {
          const { progress } = useSprite();
          const width = animate({ from: 0, to: 760, start: 0.05, end: 0.8, ease: Easing.easeOutExpo })(progress);

          return (
            <div style={{
              position: 'absolute',
              left: 260,
              top: 514,
              width,
              height: 2,
              background: palette.ink,
              opacity: 0.18,
            }} />
          );
        }

        function FinalFrame() {
          const { progress } = useSprite();
          const y = interpolate([0, 1], [32, 0], Easing.easeOutCubic)(progress);

          return (
            <div style={{
              position: 'absolute',
              inset: 0,
              display: 'grid',
              placeItems: 'center',
              opacity: clamp(progress * 1.2, 0, 1),
              transform: `translateY(${y}px)`,
            }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{
                  font: '700 22px Inter, system-ui, sans-serif',
                  color: palette.accent,
                  marginBottom: 18,
                }}>
                  Storyboard draft
                </div>
                <div style={{
                  font: '600 82px/0.94 Inter, system-ui, sans-serif',
                  letterSpacing: 0,
                  color: palette.ink,
                }}>
                  {projectTitle}
                </div>
                <div style={{
                  marginTop: 22,
                  font: '18px/1.5 Inter, system-ui, sans-serif',
                  color: palette.muted,
                }}>
                  Design system: {designSystemName}
                </div>
              </div>
            </div>
          );
        }

        function AnimationDraft() {
          return (
            <Stage width={1280} height={720} duration={8} background={palette.bg} persistKey="easel-animation-draft">
              <Sprite start={0} end={2.8}>
                <TextSprite
                  text={projectTitle}
                  x={96}
                  y={104}
                  size={72}
                  color={palette.ink}
                  weight={650}
                />
              </Sprite>

              <Sprite start={0.6} end={4.8}>
                <TextSprite
                  text={'Motion storyboard\nready for direction.'}
                  x={100}
                  y={230}
                  size={34}
                  color={palette.muted}
                  weight={450}
                  entryEase={Easing.easeOutCubic}
                />
              </Sprite>

              <Sprite start={0.9} end={5.8} keepMounted>
                <MotionBoard />
              </Sprite>

              <Sprite start={2.1} end={5.8}>
                <RectSprite
                  x={100}
                  y={470}
                  width={116}
                  height={86}
                  color={palette.accent}
                  radius={6}
                />
              </Sprite>

              <Sprite start={2.35} end={6.2}>
                <TimelineRule />
              </Sprite>

              <Sprite start={5.7} end={8}>
                <FinalFrame />
              </Sprite>
            </Stage>
          );
        }

        let bootTries = 0;
        function boot() {
          if (
            !window.Stage ||
            !window.Sprite ||
            !window.TextSprite ||
            !window.RectSprite ||
            !window.useSprite ||
            !window.Easing ||
            !window.interpolate ||
            !window.animate ||
            !window.clamp
          ) {
            if (bootTries++ < 200) {
              setTimeout(boot, 25);
              return;
            }

            document.getElementById('root').innerHTML =
              '<div style="position:absolute;inset:0;display:flex;align-items:center;' +
              'justify-content:center;text-align:center;padding:24px;color:#f8fafc;' +
              'font:14px/1.5 Inter,system-ui,sans-serif;background:#0a0a0a">' +
              'Animation engine failed to load.<br>Check that resources/animations.jsx is reachable.</div>';
            return;
          }

          ({
            Stage,
            Sprite,
            TextSprite,
            RectSprite,
            useSprite,
            Easing,
            interpolate,
            animate,
            clamp,
          } = window);
          ReactDOM.createRoot(document.getElementById('root')).render(<AnimationDraft />);
        }

        boot();
        })();
      </script>
    </body>
    </html>
    """#
  }

  static let starterComponentJavaScript = #"""
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// animations.jsx
// Reusable animation starter: Stage, Timeline, Sprite, easing helpers.
// Exports (to window): Stage, Sprite, PlaybackBar, TextSprite, ImageSprite, RectSprite,
//   useTime, useTimeline, useSprite, Easing, interpolate, animate, clamp.
//
// Usage (in an HTML file that loads React + Babel):
//
//   <Stage width={1280} height={720} duration={10} background="#f8fafc">
//     <MyScene />
//   </Stage>
//
// <Stage> auto-scales to the viewport and provides the scrubber, play/pause,
// left/right seek, space, and 0-to-reset controls, and persists the playhead.
// Inside <Stage>, any child can call useTime() to read the current
// playhead (seconds). Or wrap content in <Sprite start={1} end={4}>...</Sprite>
// to only render during that window -- children receive a `localTime` and
// `progress` via the useSprite() hook. Use Easing + interpolate()/animate()
// for tweens; TextSprite / ImageSprite / RectSprite have built-in entry/exit.
// Build YOUR scenes by composing Sprites inside a Stage.
/* END USAGE */

// Easing functions. All easings take t in [0,1] and return eased t in [0,1]
// (may overshoot for back/elastic).
const Easing = {
  linear: (t) => t,

  easeInQuad: (t) => t * t,
  easeOutQuad: (t) => t * (2 - t),
  easeInOutQuad: (t) => (t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t),

  easeInCubic: (t) => t * t * t,
  easeOutCubic: (t) => (--t) * t * t + 1,
  easeInOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1),

  easeInQuart: (t) => t * t * t * t,
  easeOutQuart: (t) => 1 - (--t) * t * t * t,
  easeInOutQuart: (t) => (t < 0.5 ? 8 * t * t * t * t : 1 - 8 * (--t) * t * t * t),

  easeInExpo: (t) => (t === 0 ? 0 : Math.pow(2, 10 * (t - 1))),
  easeOutExpo: (t) => (t === 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  easeInOutExpo: (t) => {
    if (t === 0) return 0;
    if (t === 1) return 1;
    if (t < 0.5) return 0.5 * Math.pow(2, 20 * t - 10);
    return 1 - 0.5 * Math.pow(2, -20 * t + 10);
  },

  easeInSine: (t) => 1 - Math.cos((t * Math.PI) / 2),
  easeOutSine: (t) => Math.sin((t * Math.PI) / 2),
  easeInOutSine: (t) => -(Math.cos(Math.PI * t) - 1) / 2,

  easeOutBack: (t) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
  easeInBack: (t) => {
    const c1 = 1.70158, c3 = c1 + 1;
    return c3 * t * t * t - c1 * t * t;
  },
  easeInOutBack: (t) => {
    const c1 = 1.70158, c2 = c1 * 1.525;
    return t < 0.5
      ? (Math.pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
      : (Math.pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2;
  },

  easeOutElastic: (t) => {
    const c4 = (2 * Math.PI) / 3;
    if (t === 0) return 0;
    if (t === 1) return 1;
    return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  },
};

const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

function interpolate(input, output, ease = Easing.linear) {
  return (t) => {
    if (t <= input[0]) return output[0];
    if (t >= input[input.length - 1]) return output[output.length - 1];
    for (let i = 0; i < input.length - 1; i++) {
      if (t >= input[i] && t <= input[i + 1]) {
        const span = input[i + 1] - input[i];
        const local = span === 0 ? 0 : (t - input[i]) / span;
        const easeFn = Array.isArray(ease) ? (ease[i] || Easing.linear) : ease;
        const eased = easeFn(local);
        return output[i] + (output[i + 1] - output[i]) * eased;
      }
    }
    return output[output.length - 1];
  };
}

function animate({ from = 0, to = 1, start = 0, end = 1, ease = Easing.easeInOutCubic }) {
  return (t) => {
    if (t <= start) return from;
    if (t >= end) return to;
    const local = (t - start) / (end - start);
    return from + (to - from) * ease(local);
  };
}

const TimelineContext = React.createContext({ time: 0, duration: 10, playing: false });

const useTime = () => React.useContext(TimelineContext).time;
const useTimeline = () => React.useContext(TimelineContext);

const SpriteContext = React.createContext({ localTime: 0, progress: 0, duration: 0 });
const useSprite = () => React.useContext(SpriteContext);

function Sprite({ start = 0, end = Infinity, children, keepMounted = false }) {
  const { time } = useTimeline();
  const visible = time >= start && time <= end;
  if (!visible && !keepMounted) return null;

  const duration = end - start;
  const localTime = Math.max(0, time - start);
  const progress = duration > 0 && isFinite(duration)
    ? clamp(localTime / duration, 0, 1)
    : 0;

  const value = { localTime, progress, duration, visible };

  return (
    <SpriteContext.Provider value={value}>
      {typeof children === 'function' ? children(value) : children}
    </SpriteContext.Provider>
  );
}

function TextSprite({
  text,
  x = 0, y = 0,
  size = 48,
  color = '#111',
  font = 'Inter, system-ui, sans-serif',
  weight = 600,
  entryDur = 0.45,
  exitDur = 0.35,
  entryEase = Easing.easeOutBack,
  exitEase = Easing.easeInCubic,
  align = 'left',
  letterSpacing = '0',
}) {
  const { localTime, duration } = useSprite();
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let ty = 0;

  if (localTime < entryDur) {
    const t = entryEase(clamp(localTime / entryDur, 0, 1));
    opacity = t;
    ty = (1 - t) * 16;
  } else if (localTime > exitStart) {
    const t = exitEase(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    ty = -t * 8;
  }

  const translateX = align === 'center' ? '-50%' : align === 'right' ? '-100%' : '0';

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      transform: `translate(${translateX}, ${ty}px)`,
      opacity,
      fontFamily: font,
      fontSize: size,
      fontWeight: weight,
      color,
      letterSpacing,
      whiteSpace: 'pre',
      lineHeight: 1.1,
      willChange: 'transform, opacity',
    }}>
      {text}
    </div>
  );
}

function ImageSprite({
  src,
  x = 0, y = 0,
  width = 400, height = 300,
  entryDur = 0.6,
  exitDur = 0.4,
  kenBurns = false,
  kenBurnsScale = 1.08,
  radius = 12,
  fit = 'cover',
  placeholder = null,
}) {
  const { localTime, duration } = useSprite();
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let scale = 1;

  if (localTime < entryDur) {
    const t = Easing.easeOutCubic(clamp(localTime / entryDur, 0, 1));
    opacity = t;
    scale = 0.96 + 0.04 * t;
  } else if (localTime > exitStart) {
    const t = Easing.easeInCubic(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    scale = (kenBurns ? kenBurnsScale : 1) + 0.02 * t;
  } else if (kenBurns) {
    const holdSpan = exitStart - entryDur;
    const holdT = holdSpan > 0 ? (localTime - entryDur) / holdSpan : 0;
    scale = 1 + (kenBurnsScale - 1) * holdT;
  }

  const content = placeholder ? (
    <div style={{
      width: '100%', height: '100%',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'repeating-linear-gradient(135deg, #eef2f7 0 10px, #d9e1ea 10px 20px)',
      color: '#64748b',
      fontFamily: 'JetBrains Mono, ui-monospace, monospace',
      fontSize: 13,
      letterSpacing: '0.04em',
      textTransform: 'uppercase',
    }}>
      {placeholder.label || 'image'}
    </div>
  ) : (
    <img src={src} alt="" style={{ width: '100%', height: '100%', objectFit: fit, display: 'block' }} />
  );

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      width, height,
      opacity,
      transform: `scale(${scale})`,
      transformOrigin: 'center',
      borderRadius: radius,
      overflow: 'hidden',
      willChange: 'transform, opacity',
    }}>
      {content}
    </div>
  );
}

function RectSprite({
  x = 0, y = 0,
  width = 100, height = 100,
  color = '#111',
  radius = 8,
  entryDur = 0.4,
  exitDur = 0.3,
  render,
}) {
  const spriteCtx = useSprite();
  const { localTime, duration } = spriteCtx;
  const exitStart = Math.max(0, duration - exitDur);

  let opacity = 1;
  let scale = 1;

  if (localTime < entryDur) {
    const t = Easing.easeOutBack(clamp(localTime / entryDur, 0, 1));
    opacity = clamp(localTime / entryDur, 0, 1);
    scale = 0.4 + 0.6 * t;
  } else if (localTime > exitStart) {
    const t = Easing.easeInQuad(clamp((localTime - exitStart) / exitDur, 0, 1));
    opacity = 1 - t;
    scale = 1 - 0.15 * t;
  }

  const overrides = render ? render(spriteCtx) : {};

  return (
    <div style={{
      position: 'absolute',
      left: x, top: y,
      width, height,
      background: color,
      borderRadius: radius,
      opacity,
      transform: `scale(${scale})`,
      transformOrigin: 'center',
      willChange: 'transform, opacity',
      ...overrides,
    }} />
  );
}

function Stage({
  width = 1280,
  height = 720,
  duration = 10,
  background = '#f8fafc',
  fps = 60,
  loop = true,
  autoplay = true,
  persistKey = 'animstage',
  children,
}) {
  const [time, setTime] = React.useState(() => {
    try {
      const v = parseFloat(localStorage.getItem(persistKey + ':t') || '0');
      return isFinite(v) ? clamp(v, 0, duration) : 0;
    } catch { return 0; }
  });
  const [playing, setPlaying] = React.useState(autoplay);
  const [hoverTime, setHoverTime] = React.useState(null);
  const [scale, setScale] = React.useState(1);

  const stageRef = React.useRef(null);
  const canvasRef = React.useRef(null);
  const rafRef = React.useRef(null);
  const lastTsRef = React.useRef(null);

  React.useEffect(() => {
    try { localStorage.setItem(persistKey + ':t', String(time)); } catch {}
  }, [time, persistKey]);

  React.useEffect(() => {
    if (!stageRef.current) return;
    const el = stageRef.current;
    const measure = () => {
      const barH = 44;
      const s = Math.min(
        el.clientWidth / width,
        (el.clientHeight - barH) / height
      );
      setScale(Math.max(0.05, s));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    window.addEventListener('resize', measure);
    return () => {
      ro.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, [width, height]);

  React.useEffect(() => {
    if (!playing) {
      lastTsRef.current = null;
      return;
    }
    const step = (ts) => {
      if (lastTsRef.current == null) lastTsRef.current = ts;
      const dt = (ts - lastTsRef.current) / 1000;
      lastTsRef.current = ts;
      setTime((t) => {
        let next = t + dt;
        if (next >= duration) {
          if (loop) next = next % duration;
          else { next = duration; setPlaying(false); }
        }
        return next;
      });
      rafRef.current = requestAnimationFrame(step);
    };
    rafRef.current = requestAnimationFrame(step);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      lastTsRef.current = null;
    };
  }, [playing, duration, loop]);

  React.useEffect(() => {
    const onKey = (e) => {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
      if (e.code === 'Space') {
        e.preventDefault();
        setPlaying(p => !p);
      } else if (e.code === 'ArrowLeft') {
        setTime(t => clamp(t - (e.shiftKey ? 1 : 0.1), 0, duration));
      } else if (e.code === 'ArrowRight') {
        setTime(t => clamp(t + (e.shiftKey ? 1 : 0.1), 0, duration));
      } else if (e.key === '0' || e.code === 'Home') {
        setTime(0);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [duration]);

  const displayTime = hoverTime != null ? hoverTime : time;

  const ctxValue = React.useMemo(
    () => ({ time: displayTime, duration, playing, setTime, setPlaying }),
    [displayTime, duration, playing]
  );

  return (
    <div
      ref={stageRef}
      style={{
        position: 'absolute', inset: 0,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center',
        background: '#0a0a0a',
        fontFamily: 'Inter, system-ui, sans-serif',
      }}
    >
      <div style={{
        flex: 1,
        width: '100%',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        overflow: 'hidden',
        minHeight: 0,
      }}>
        <div
          ref={canvasRef}
          style={{
            width, height,
            background,
            position: 'relative',
            transform: `scale(${scale})`,
            transformOrigin: 'center',
            flexShrink: 0,
            boxShadow: '0 20px 60px rgba(0,0,0,0.4)',
            overflow: 'hidden',
          }}
        >
          <TimelineContext.Provider value={ctxValue}>
            {children}
          </TimelineContext.Provider>
        </div>
      </div>

      <PlaybackBar
        time={displayTime}
        actualTime={time}
        duration={duration}
        playing={playing}
        onPlayPause={() => setPlaying(p => !p)}
        onReset={() => { setTime(0); }}
        onSeek={(t) => setTime(t)}
        onHover={(t) => setHoverTime(t)}
      />
    </div>
  );
}

function PlaybackBar({ time, duration, playing, onPlayPause, onReset, onSeek, onHover }) {
  const trackRef = React.useRef(null);
  const [dragging, setDragging] = React.useState(false);

  const timeFromEvent = React.useCallback((e) => {
    const rect = trackRef.current.getBoundingClientRect();
    const x = clamp((e.clientX - rect.left) / rect.width, 0, 1);
    return x * duration;
  }, [duration]);

  const onTrackMove = (e) => {
    if (!trackRef.current) return;
    const t = timeFromEvent(e);
    if (dragging) {
      onSeek(t);
    } else {
      onHover(t);
    }
  };

  const onTrackLeave = () => {
    if (!dragging) onHover(null);
  };

  const onTrackDown = (e) => {
    setDragging(true);
    const t = timeFromEvent(e);
    onSeek(t);
    onHover(null);
  };

  React.useEffect(() => {
    if (!dragging) return;
    const onUp = () => setDragging(false);
    const onMove = (e) => {
      if (!trackRef.current) return;
      const t = timeFromEvent(e);
      onSeek(t);
    };
    window.addEventListener('mouseup', onUp);
    window.addEventListener('mousemove', onMove);
    return () => {
      window.removeEventListener('mouseup', onUp);
      window.removeEventListener('mousemove', onMove);
    };
  }, [dragging, timeFromEvent, onSeek]);

  const pct = duration > 0 ? (time / duration) * 100 : 0;
  const fmt = (t) => {
    const total = Math.max(0, t);
    const m = Math.floor(total / 60);
    const s = Math.floor(total % 60);
    const cs = Math.floor((total * 100) % 100);
    return `${String(m).padStart(1, '0')}:${String(s).padStart(2, '0')}.${String(cs).padStart(2, '0')}`;
  };

  const mono = 'JetBrains Mono, ui-monospace, SFMono-Regular, monospace';

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '8px 16px',
      background: 'rgba(20,20,20,0.92)',
      borderTop: '1px solid rgba(255,255,255,0.08)',
      width: '100%',
      maxWidth: 680,
      alignSelf: 'center',
      borderRadius: 8,
      color: '#f8fafc',
      fontFamily: 'Inter, system-ui, sans-serif',
      userSelect: 'none',
      flexShrink: 0,
    }}>
      <IconButton onClick={onReset} title="Return to start (0)">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M3 2v10M12 2L5 7l7 5V2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round"/>
        </svg>
      </IconButton>
      <IconButton onClick={onPlayPause} title="Play/pause (space)">
        {playing ? (
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <rect x="3" y="2" width="3" height="10" fill="currentColor"/>
            <rect x="8" y="2" width="3" height="10" fill="currentColor"/>
          </svg>
        ) : (
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M3 2l9 5-9 5V2z" fill="currentColor"/>
          </svg>
        )}
      </IconButton>

      <div style={{
        fontFamily: mono,
        fontSize: 12,
        fontVariantNumeric: 'tabular-nums',
        width: 64, textAlign: 'right',
        color: '#f8fafc',
      }}>
        {fmt(time)}
      </div>

      <div
        ref={trackRef}
        onMouseMove={onTrackMove}
        onMouseLeave={onTrackLeave}
        onMouseDown={onTrackDown}
        style={{
          flex: 1,
          height: 22,
          position: 'relative',
          cursor: 'pointer',
          display: 'flex', alignItems: 'center',
        }}
      >
        <div style={{
          position: 'absolute',
          left: 0, right: 0, height: 4,
          background: 'rgba(255,255,255,0.12)',
          borderRadius: 2,
        }}/>
        <div style={{
          position: 'absolute',
          left: 0, width: `${pct}%`, height: 4,
          background: 'oklch(72% 0.12 250)',
          borderRadius: 2,
        }}/>
        <div style={{
          position: 'absolute',
          left: `${pct}%`, top: '50%',
          width: 12, height: 12,
          marginLeft: -6, marginTop: -6,
          background: '#fff',
          borderRadius: 6,
          boxShadow: '0 2px 4px rgba(0,0,0,0.4)',
        }}/>
      </div>

      <div style={{
        fontFamily: mono,
        fontSize: 12,
        fontVariantNumeric: 'tabular-nums',
        width: 64, textAlign: 'left',
        color: 'rgba(248,250,252,0.55)',
      }}>
        {fmt(duration)}
      </div>
    </div>
  );
}

function IconButton({ children, onClick, title }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      title={title}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: 28, height: 28,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: hover ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.04)',
        border: '1px solid rgba(255,255,255,0.1)',
        borderRadius: 6,
        color: '#f8fafc',
        cursor: 'pointer',
        padding: 0,
        transition: 'background 120ms',
      }}
    >
      {children}
    </button>
  );
}

Object.assign(window, {
  Easing, interpolate, animate, clamp,
  TimelineContext, useTime, useTimeline,
  Sprite, SpriteContext, useSprite,
  TextSprite, ImageSprite, RectSprite,
  Stage, PlaybackBar,
});
"""#

  private static func escapedHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  private static func javaScriptStringLiteral(_ value: String) -> String {
    let escaped = value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
      .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
      .replacingOccurrences(of: "</", with: "<\\/")
    return "\"\(escaped)\""
  }
}
