// Renders preview pictures of a creature GLB, without Blender or Studio.
// Usage (from the repo root, after `npm install` in this folder):
//   node scripts/models/preview/render.mjs models/creatures/Fly.glb OUT_DIR
// Reads the JSON written next to the GLB (moving parts and their hinges) and writes:
//   views.png        front, three quarter, side and top, with the outline look
//   views-plain.png  the same without the Outline and wing rim parts
//   motion.gif       one loop of the moving parts (wings, legs), three quarter view
// Uses the Playwright Chromium already on the machine.
import { createRequire } from "node:module";
import { createServer } from "node:http";
import { readFileSync, mkdirSync } from "node:fs";
import { resolve, dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

// Playwright comes from the machine (cloud sessions have it installed globally).
const { chromium } = createRequire(import.meta.url)("playwright");
const here = dirname(fileURLToPath(import.meta.url));
const [glbPath, outDir] = process.argv.slice(2).map((p) => resolve(p));
const info = JSON.parse(readFileSync(glbPath.replace(/\.glb$/, ".json"), "utf8"));
mkdirSync(outDir, { recursive: true });

const types = { ".html": "text/html", ".js": "text/javascript", ".glb": "model/gltf-binary" };
const server = createServer((req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  const file = url === "/model.glb" ? glbPath : join(here, url);
  try {
    res.writeHead(200, { "content-type": types[extname(file)] || "application/octet-stream" });
    res.end(readFileSync(file));
  } catch {
    res.writeHead(404).end();
  }
}).listen(0);
const port = server.address().port;

const SIZE = 600;
const browser = await chromium.launch({ args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE } });
await page.goto(`http://localhost:${port}/page.html`);
await page.waitForFunction(() => window.ready);
await page.evaluate(([i, s]) => window.setup("/model.glb", i, s), [info, SIZE]);

async function shot(opts, file) {
  await page.evaluate((o) => window.draw(o), opts);
  await page.screenshot({ path: file });
}

const plain = Object.keys(info.parts).filter((n) => n.startsWith("Outline") || n.startsWith("WingRim"));
const views = [
  ["front", { azimuth: 0, elevation: 5 }],
  ["three-quarter", { azimuth: -40, elevation: 15 }],
  ["side", { azimuth: -90, elevation: 0 }],
  ["top", { azimuth: 180, elevation: 89 }],
];
const tmp = join(outDir, "frames");
mkdirSync(tmp, { recursive: true });
// A model can swap in its own camera angles, e.g. to show a dip from above.
for (const [name, v] of Object.entries(info.previewViews || {})) {
  const i = views.findIndex(([n]) => n === name);
  if (i >= 0) views[i][1] = v;
}
// Preview-only parts (like the rain shadow) show only in the motion clip.
const only = info.previewOnly || [];
for (const [look, hide] of [["views", only], ["views-plain", [...plain, ...only]]]) {
  const files = [];
  for (const [name, v] of views) {
    const f = join(tmp, `${look}-${name}.png`);
    await shot({ ...v, hide }, f);
    files.push(f);
  }
  execFileSync("python3", [join(here, "sheet.py"), join(outDir, `${look}.png`), ...files]);
}

// Motion clips: one loop of every moving part listed in the JSON. Parts
// that move on a game event ("onEvent") get one clip per event: the first
// is motion.gif, the rest <event>.gif.
const events = [...new Set((info.moving || []).map((m) => m.onEvent).filter(Boolean))];
const clips = (info.moving || []).length ? (events.length ? events : [null]) : [];
for (const [n, event] of clips.entries()) {
  const frames = [];
  const N = (event && info.eventFrames?.[event]) || info.motionFrames || 32;   // 40 ms a frame
  for (let i = 0; i < N; i++) {
    const f = join(tmp, `move-${n}-${String(i).padStart(2, "0")}.png`);
    const view = (event && info.eventViews?.[event]) || info.motionView || { azimuth: -35, elevation: 12 };
    await shot({ ...view, time: i / N, event }, f);
    frames.push(f);
  }
  const name = n === 0 ? "motion.gif" : `${event}.gif`;
  execFileSync("python3", [join(here, "sheet.py"), "--gif", join(outDir, name), ...frames]);
}
await browser.close();
server.close();
console.log("written to", outDir);
