import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { parseFig, parseFigBinary, resolveVectorNodePaths } from "openfig-core";

const parserVersion = "0.3.7";
const inputPath = process.argv[2];
const outputPath = process.argv[3];
// Optional: directory (under the design system's .easel/assets) where extracted
// binary assets (document thumbnail + image fills) are written. Paths emitted in
// the JSON are relative to this directory.
const assetsDir = process.argv[4] || null;

if (!inputPath || !outputPath) {
  console.error("Usage: node fig-importer.mjs <input.fig> <output.json> [assetsDir]");
  process.exit(2);
}

const bytes = readFileSync(inputPath);
const data = new Uint8Array(bytes.buffer, bytes.byteOffset, bytes.byteLength);

let document;
try {
  document = parseFig(data);
} catch {
  document = parseFigBinary(data);
}

const nodes = Array.isArray(document.nodes)
  ? document.nodes
  : Array.isArray(document.message?.nodeChanges)
    ? document.message.nodeChanges
    : [];
const nodeById = new Map(nodes.map((node) => [nodeId(node), node]));
const childCountById = new Map();

for (const node of nodes) {
  const parentID = parentId(node);
  if (!parentID) continue;
  childCountById.set(parentID, (childCountById.get(parentID) ?? 0) + 1);
}

const depthMemo = new Map();
const pageMemo = new Map();

// Extract embedded binary assets (document thumbnail + image fills). The image
// map is keyed by hash so node image fills can reference the written file.
const imageRefByHash = new Map();
const imageAssets = [];
let thumbnailPath = null;

if (assetsDir) {
  try {
    mkdirSync(assetsDir, { recursive: true });
    if (document.thumbnail && document.thumbnail.length) {
      const ext = imageExtension(document.thumbnail);
      const name = `thumbnail.${ext}`;
      writeFileSync(join(assetsDir, name), document.thumbnail);
      thumbnailPath = name;
    }
    if (document.images instanceof Map && document.images.size) {
      const imagesDir = join(assetsDir, "images");
      mkdirSync(imagesDir, { recursive: true });
      for (const [key, value] of document.images) {
        if (!value || !value.length) continue;
        const safeKey = String(key).replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 64) || `img${imageAssets.length}`;
        const ext = imageExtension(value);
        const fileName = `${safeKey}.${ext}`;
        writeFileSync(join(imagesDir, fileName), value);
        const relativePath = `images/${fileName}`;
        imageRefByHash.set(String(key), relativePath);
        imageAssets.push({ name: safeKey, path: relativePath });
      }
    }
  } catch (error) {
    // Asset extraction is best-effort; node data is still emitted without it.
  }
}

let vectorPathBudget = 8000;

function nodeId(node) {
  return idFromGuid(node?.guid);
}

function idFromGuid(guid) {
  if (!guid) return "";
  return `${guid.sessionID}:${guid.localID}`;
}

function parentId(node) {
  return idFromGuid(node?.parentIndex?.guid) || null;
}

function depthOf(node) {
  const id = nodeId(node);
  if (depthMemo.has(id)) return depthMemo.get(id);

  const parentID = parentId(node);
  if (!parentID || !nodeById.has(parentID)) {
    depthMemo.set(id, 0);
    return 0;
  }

  const depth = depthOf(nodeById.get(parentID)) + 1;
  depthMemo.set(id, depth);
  return depth;
}

function pageNameOf(node) {
  const id = nodeId(node);
  if (pageMemo.has(id)) return pageMemo.get(id);

  if (node?.type === "CANVAS" && node?.name) {
    pageMemo.set(id, node.name);
    return node.name;
  }

  const parentID = parentId(node);
  const pageName = parentID && nodeById.has(parentID)
    ? pageNameOf(nodeById.get(parentID))
    : null;
  pageMemo.set(id, pageName);
  return pageName;
}

function colorsFromPaints(paints) {
  if (!Array.isArray(paints)) return [];

  const colors = [];
  for (const paint of paints) {
    if (!paint || paint.visible === false) continue;
    if (paint.type !== "SOLID" || !paint.color) continue;
    colors.push(hexColor(paint.color, paint.opacity));
  }
  return colors;
}

function imageRefFromPaints(paints) {
  if (!Array.isArray(paints)) return null;
  for (const paint of paints) {
    if (!paint || paint.visible === false) continue;
    if (typeof paint.type === "string" && paint.type.includes("IMAGE")) {
      const key = imageHashKey(paint.image?.hash) ?? imageHashKey(paint.imageThumbnail?.hash);
      if (key && imageRefByHash.has(key)) {
        return imageRefByHash.get(key);
      }
    }
  }
  return null;
}

function imageHashKey(hash) {
  if (!hash) return null;
  if (typeof hash === "string") return hash;
  try {
    return Array.from(hash).map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch {
    return null;
  }
}

function imageExtension(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "jpg";
  if (bytes.length >= 4 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46) return "gif";
  return "png";
}

function hexColor(color, opacity) {
  const alpha = clamp01((color.a ?? 1) * (opacity ?? 1));
  const channels = [color.r, color.g, color.b].map((value) =>
    Math.round(clamp01(value) * 255).toString(16).padStart(2, "0")
  );
  const alphaHex = alpha < 1
    ? Math.round(alpha * 255).toString(16).padStart(2, "0")
    : "";
  return `#${channels.join("")}${alphaHex}`.toUpperCase();
}

function clamp01(value) {
  if (Number.isNaN(value)) return 0;
  return Math.max(0, Math.min(1, value));
}

function numberValue(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function textValue(node) {
  const text = node?.textData?.characters;
  if (typeof text !== "string") return null;
  return text.length > 240 ? `${text.slice(0, 240)}...` : text;
}

function cornerRadius(node) {
  return numberValue(node?.cornerRadius)
    ?? numberValue(node?.rectangleTopLeftCornerRadius)
    ?? numberValue(node?.rectangleTopRightCornerRadius)
    ?? numberValue(node?.rectangleBottomLeftCornerRadius)
    ?? numberValue(node?.rectangleBottomRightCornerRadius);
}

function effectTypes(node) {
  if (!Array.isArray(node?.effects)) return [];
  return node.effects
    .filter((effect) => effect && effect.visible !== false)
    .map((effect) => effect.type)
    .filter((type) => typeof type === "string" && type.length > 0);
}

const VECTOR_TYPES = new Set([
  "VECTOR", "STAR", "LINE", "REGULAR_POLYGON", "BOOLEAN_OPERATION", "ELLIPSE",
]);

function vectorPath(node) {
  if (vectorPathBudget <= 0) return null;
  if (!VECTOR_TYPES.has(node?.type)) return null;
  try {
    const resolved = resolveVectorNodePaths(document, node);
    const paths = [...(resolved?.fill ?? []), ...(resolved?.stroke ?? [])]
      .map((entry) => entry?.svgPath)
      .filter((svg) => typeof svg === "string" && svg.length > 0);
    if (!paths.length) return null;
    vectorPathBudget -= 1;
    const combined = paths.join(" ");
    return combined.length > 4000 ? null : combined;
  } catch {
    return null;
  }
}

const normalizedNodes = nodes
  .filter((node) => node && nodeId(node))
  .map((node) => ({
    id: nodeId(node),
    type: String(node.type ?? "UNKNOWN"),
    name: String(node.name ?? ""),
    parentID: parentId(node),
    pageName: pageNameOf(node),
    depth: depthOf(node),
    x: numberValue(node.transform?.m02),
    y: numberValue(node.transform?.m12),
    width: numberValue(node.size?.x),
    height: numberValue(node.size?.y),
    childCount: childCountById.get(nodeId(node)) ?? 0,
    opacity: numberValue(node.opacity),
    fillColors: colorsFromPaints(node.fillPaints),
    strokeColors: colorsFromPaints(node.strokePaints),
    strokeWeight: numberValue(node.strokeWeight),
    fontFamily: node.fontName?.family ?? null,
    fontStyle: node.fontName?.style ?? null,
    fontSize: numberValue(node.fontSize),
    textAlign: typeof node.textAlignHorizontal === "string" ? node.textAlignHorizontal : null,
    text: textValue(node),
    cornerRadius: cornerRadius(node),
    effectTypes: effectTypes(node),
    imageRef: imageRefFromPaints(node.fillPaints),
    vectorPath: vectorPath(node),
  }));

const pageCount = normalizedNodes.filter((node) => node.type === "CANVAS").length;
const output = {
  parser: {
    name: "openfig-core",
    version: parserVersion
  },
  document: {
    nodeCount: normalizedNodes.length,
    pageCount,
    thumbnailPath,
    imageAssets
  },
  nodes: normalizedNodes
};

writeFileSync(outputPath, JSON.stringify(output, null, 2));
