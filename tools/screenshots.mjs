/* Captures the home and a content page in both themes, desktop and phone.
   Usage: node tools/screenshots.mjs <out_dir> */
import { chromium } from '/home/rafaelejosi/.hermes/hermes-agent/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';

const BASE = 'http://127.0.0.1:8900/wiki';
const OUT = process.argv[2] || '/tmp/wiki-shots';
mkdirSync(OUT, { recursive: true });

const SHOTS = [
  ['home', '/index.html'],
  ['content', '/CONTRIBUTING.html'],
];

const browser = await chromium.launch({ channel: 'chrome' });

for (const [label, path] of SHOTS) {
  for (const [theme, w, h, suffix] of [
    ['dark', 1280, 900, 'desktop'],
    ['light', 1280, 900, 'desktop'],
    ['dark', 390, 844, 'mobile'],
  ]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h } });
    const page = await ctx.newPage();
    await page.addInitScript(t => {
      try { localStorage.setItem('piano-wiki-theme', t); } catch (e) {}
    }, theme);
    await page.goto(BASE + path, { waitUntil: 'domcontentloaded', timeout: 30_000 });
    await page.waitForTimeout(500);
    /* fullPage so lower sections (Templates, footer) are captured too — a
       viewport-only shot cuts them off and hides contrast problems. */
    const file = `${OUT}/${label}-${theme}-${suffix}.png`;
    await page.screenshot({ path: file, fullPage: true });
    console.log(file);
    await ctx.close();
  }
}

await browser.close();