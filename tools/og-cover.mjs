/* Renders the OpenGraph social card (assets/og-cover.png).
   1200x630 is the size LinkedIn, Slack, Discord and X all crop to.

   Uses the system Chrome via Playwright so the card is rendered by the same
   browser that will display it — no headless-image-library dependency, and no
   mismatch between what CSS says and what is rasterised.

   Usage: node tools/og-cover.mjs */
import { chromium } from '/home/rafaelejosi/.hermes/hermes-agent/node_modules/playwright/index.mjs';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'assets', 'og-cover.png');

const logo = readFileSync(join(ROOT, 'assets', 'logo.svg'), 'utf8');

/* Inline the SVG so the card does not depend on a file:// fetch inside the
   render pass. */
const logoMarkup = logo
  .replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72"')
  .replace(/\swidth="565"\s/, ' ')
  .replace(/\sheight="594"\s/, ' ');

const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    width:1200px; height:630px; overflow:hidden;
    background:#0f1115;
    font-family:Inter, -apple-system, "Segoe UI", Roboto, sans-serif;
    color:#e8eaed;
    display:flex; flex-direction:column; justify-content:space-between;
    padding:64px 72px;
    position:relative;
  }
  /* Brand glow, kept subtle so text contrast stays high. */
  body::before {
    content:''; position:absolute; right:-160px; top:-160px;
    width:560px; height:560px; border-radius:50%;
    background:radial-gradient(circle, rgba(224,137,90,.22) 0%, rgba(224,137,90,0) 70%);
  }
  .mark { width:72px; height:72px; border-radius:16px; position:relative; z-index:1; }
  .kicker {
    font-size:20px; font-weight:700; letter-spacing:.14em; text-transform:uppercase;
    color:#e0895a; margin-bottom:20px; position:relative; z-index:1;
  }
  h1 {
    font-size:76px; font-weight:700; letter-spacing:-.03em; line-height:1.05;
    margin-bottom:24px; position:relative; z-index:1;
  }
  .sub { font-size:28px; color:#9aa3af; line-height:1.45; max-width:900px; position:relative; z-index:1; }
  .foot {
    display:flex; align-items:center; gap:14px;
    font-size:22px; color:#6b7480; position:relative; z-index:1;
  }
  .dot { width:5px; height:5px; border-radius:50%; background:#e0895a; display:inline-block; }
</style></head>
<body>
  <div class="mark">${logoMarkup}</div>
  <div>
    <div class="kicker">Piano LouvorJA</div>
    <h1>Developer Wiki</h1>
    <div class="sub">Onboarding público para contribuidores e agentes de IA no ecossistema Piano LouvorJA.</div>
  </div>
  <div class="foot"><span>piano-louvor-ja.github.io/wiki</span><span class="dot"></span><span>MIT</span></div>
</body></html>`;

const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--disable-dev-shm-usage', '--no-sandbox', '--disable-gpu'],
});
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.setContent(html, { waitUntil: 'load' });
await page.screenshot({ path: OUT });
await browser.close();
console.log(`OK — ${OUT}`);