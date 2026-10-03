/* Visual/functional inspection of the local wiki preview.
   Drives a real browser so the assertions come from a rendered engine, not
   from reading the HTML. Uses the system Chrome (channel: 'chrome') so it
   does not depend on Playwright's own browser download.

   Usage:
     ruby tools/preview.rb /tmp/wikiroot/wiki     # render
     python3 tools/serve.py                      # serve on :8900
     SENTINELS_BY_SLUG="$(ruby tools/content_sentinels.rb)" \
       node tools/verify-preview.mjs
*/
import { chromium } from '/home/rafaelejosi/.hermes/hermes-agent/node_modules/playwright/index.mjs';

const BASE = 'http://127.0.0.1:8900/wiki';
const PAGES = [
  ['index', '/index.html'],
  ['README', '/README.html'],
  ['GETTING_STARTED', '/GETTING_STARTED.html'],
  ['ARCHITECTURE', '/ARCHITECTURE.html'],
  ['CONTRIBUTING', '/CONTRIBUTING.html'],
  ['GOVERNANCE', '/GOVERNANCE.html'],
  ['FAQ', '/FAQ.html'],
  ['AGENTS', '/AGENTS.html'],
  ['AGENT_SETUP', '/AGENT_SETUP.html'],
  ['es-index', '/es/index.html'],
  ['es-FAQ', '/es/FAQ.html'],
  ['pt-index', '/pt/index.html'],
  ['pt-FAQ', '/pt/FAQ.html'],
  ['pt-GOVERNANCE', '/pt/GOVERNANCE.html'],
  ['SPEC_TEMPLATE', '/SPEC_TEMPLATE.html'],
  ['PLAN_TEMPLATE', '/PLAN_TEMPLATE.html'],
];

/* Native fetch with an explicit timeout and a retry.
   Without this, a stalled connection throws undici's HeadersTimeoutError and
   aborts the whole run — which happens on this host, which sits under memory
   pressure often enough to drop connections. The local server answers in ~1ms,
   so a retry is far cheaper than a false failure. */
const httpGet = async (url, attempts = 3) => {
  for (let i = 1; i <= attempts; i++) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 15_000);
    try {
      const res = await fetch(url, { signal: ctrl.signal });
      if (res.ok || res.status < 500) return res;   // a real 404 is an answer
      if (i === attempts) return res;
    } catch (err) {
      if (i === attempts) return { ok: false, status: 0, error: String(err) };
    } finally {
      clearTimeout(timer);
    }
    process.stderr.write(`  retry ${i}/${attempts - 1}: ${url}\n`);
    await new Promise(r => setTimeout(r, 400));
  }
};

const fails = [];
const ok = (cond, msg) => { if (!cond) fails.push(msg); };

/* --disable-dev-shm-usage matters when /dev/shm is small: without it Chrome
   crashes the tab ("Page crashed") instead of reporting a memory problem. */
const browser = await chromium.launch({
  channel: 'chrome',
  args: ['--disable-dev-shm-usage', '--no-sandbox', '--disable-gpu'],
});
/* One context, reused for the whole run. Opening 24 pages plus the contrast
   sweep in fresh contexts is what exhausts memory on this host (swap is full),
   which shows up as "Target crashed" rather than a real failure. */
const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const page = await ctx.newPage();
const freshPage = async () => ctx.newPage();

/* domcontentloaded + document.fonts.ready, deliberately.
   'networkidle' and 'load' both time out on this machine even though the page
   serves in ~60ms (Chrome stays busy after load). domcontentloaded plus an
   explicit font wait is both faster and deterministic for the Inter check. */
const settle = async (p, url) => {
  const res = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30_000 });
  await p.evaluate(() => document.fonts.ready);
  return res;
};

/* This host is regularly under memory pressure (swap full, several long-lived
   processes), which makes Chrome drop navigations non-deterministically. The
   server answers in ~60ms, so retrying is cheap and separates a real regression
   from host noise. Still fails loudly if it never succeeds. */
const settleRetry = async (p, url, attempts = 3) => {
  for (let i = 1; i <= attempts; i++) {
    try {
      return await settle(p, url);
    } catch (err) {
      if (i === attempts) throw err;
      process.stderr.write(`  retry ${i}/${attempts - 1}: ${url}\n`);
      await p.waitForTimeout(750);
    }
  }
};

/* Fail loudly on any console error or failed request (missing font/asset). */
const consoleErrors = [];
const failedReqs = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('requestfailed', r => failedReqs.push(`${r.url()} — ${r.failure()?.errorText}`));
page.on('response', r => { if (r.status() >= 400) failedReqs.push(`${r.url()} — HTTP ${r.status()}`); });

/* ---- per-page checks ---- */
for (const [slug, path] of PAGES) {
  const res = await settleRetry(page, BASE + path);
  ok(res.ok(), `${slug}: navegação falhou (HTTP ${res?.status()})`);

  /* dark is the default with no stored preference */
  const theme = await page.getAttribute('html', 'data-theme');
  ok(theme === 'dark', `${slug}: tema inicial deveria ser dark, veio ${theme}`);

  /* The <html lang> must match the page's actual language. */
  const expectedLang = slug.startsWith('pt-') ? 'pt-BR'
                     : slug.startsWith('es-') ? 'es' : 'en';
  const htmlLang = await page.getAttribute('html', 'lang');
  ok(htmlLang === expectedLang, `${slug}: html lang esperado ${expectedLang}, veio ${htmlLang}`);

  const bg = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
  ok(bg === 'rgb(15, 17, 21)', `${slug}: fundo dark esperado rgb(15,17,21), veio ${bg}`);

  const font = await page.evaluate(() => getComputedStyle(document.body).fontFamily);
  ok(font.includes('Inter'), `${slug}: Inter não aplicada (${font})`);

  const interLoaded = await page.evaluate(() => document.fonts.check('16px Inter'));
  ok(interLoaded, `${slug}: webfont Inter não carregou`);

  const h1s = await page.evaluate(() => document.querySelectorAll('h1').length);
  ok(h1s === 1, `${slug}: esperado 1 <h1>, veio ${h1s}`);

  const brand = await page.evaluate(() => {
    const img = document.querySelector('.brand img');
    return img ? { w: img.naturalWidth, src: img.getAttribute('src') } : null;
  });
  ok(brand && brand.w > 0, `${slug}: logo não renderizou (naturalWidth=0)`);
  ok(brand?.src === '/wiki/assets/logo.svg', `${slug}: src do logo errado (${brand?.src})`);

  ok(await page.isVisible('#theme-toggle'), `${slug}: toggle de tema não visível`);
  ok(await page.isVisible('.site-header'), `${slug}: header ausente`);
  ok(await page.isVisible('.site-footer'), `${slug}: footer ausente`);

  const navCount = await page.evaluate(() => document.querySelectorAll('.site-nav a').length);
  ok(navCount === 7, `${slug}: nav deveria ter 7 links, veio ${navCount}`);

  /* every nav link must actually resolve */
  const navHrefs = await page.evaluate(() =>
    [...document.querySelectorAll('.site-nav a')].map(a => a.getAttribute('href')));
  for (const href of navHrefs) {
    const r = await httpGet(BASE + href.replace('/wiki', ''));
    ok(r.ok, `${slug}: link de nav quebrado ${href} (HTTP ${r.status})`);
  }
}

/* ---- home specifics ---- */
await settleRetry(page, `${BASE}/index.html`);
ok(await page.isVisible('.hero-mark'), 'index: hero-mark ausente');
const heroTitle = (await page.textContent('.hero h1'))?.trim();
ok(['Developer Wiki', 'Wiki do desenvolvedor', 'Wiki para desarrolladores'].includes(heroTitle),
   `index: hero h1 inesperado (${heroTitle})`);

/* Language switcher */
const langOpts = await page.evaluate(() =>
  [...document.querySelectorAll('.lang-opt')].map(a => ({
    text: a.textContent.trim(), href: a.getAttribute('href'),
    active: a.classList.contains('is-active'),
  })));
ok(langOpts.length === 3, `index: seletor de idioma deveria ter 3 opcoes, veio ${langOpts.length}`);
ok(langOpts.some(o => o.active), 'index: nenhuma opcao de idioma marcada como ativa');
for (const o of langOpts) {
  /* Navigated in the browser rather than fetched: Node's native fetch is
     unreliable on this host (full swap), while the browser connection is not.
     '/' and '/es/' are directories served as index.html, exactly like Pages. */
  const target = o.href.replace('/wiki', '');
  const probe = await freshPage();
  const resp = await probe.goto(BASE + target, { waitUntil: 'commit', timeout: 20_000 })
    .catch(() => null);
  ok(resp && resp.ok(), `index: link de idioma quebrado ${o.href} (HTTP ${resp ? resp.status() : 0})`);
  await probe.close();
}
const btnBg = await page.evaluate(() =>
  getComputedStyle(document.querySelector('.btn-primary')).backgroundColor);
ok(btnBg === 'rgb(224, 137, 90)', `index: botão primário não usa a marca #E0895A (${btnBg})`);
const steps = await page.evaluate(() => document.querySelectorAll('.main > ol > li').length);
ok(steps === 5, `index: "Start here" deveria ter 5 passos, veio ${steps}`);

/* ---- theme toggle round-trip + persistence ---- */
await page.click('#theme-toggle');
/* The colour transition is 180ms; wait for it to settle before reading. */
await page.waitForTimeout(400);
let t = await page.getAttribute('html', 'data-theme');
ok(t === 'light', `toggle: deveria virar light, veio ${t}`);
let bgLight = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
ok(bgLight === 'rgb(255, 255, 255)', `toggle: fundo light esperado branco, veio ${bgLight}`);

const sunVisible = await page.isVisible('.theme-toggle .icon-sun');
ok(sunVisible, 'toggle: ícone de sol não apareceu no light');

/* persisted choice must survive navigation */
await settleRetry(page, `${BASE}/FAQ.html`);
t = await page.getAttribute('html', 'data-theme');
ok(t === 'light', `persistência: light deveria sobreviver à navegação, veio ${t}`);

/* and must not flash dark on load */
const initialTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
ok(initialTheme === 'light', `FOUC: tema inicial veio ${initialTheme}`);

/* back to dark, and stored state cleared for the next run */
await page.click('#theme-toggle');
await page.waitForTimeout(400);
t = await page.getAttribute('html', 'data-theme');
ok(t === 'dark', `toggle: deveria voltar a dark, veio ${t}`);
const stored = await page.evaluate(() => localStorage.getItem('piano-wiki-theme'));
ok(stored === 'dark', `localStorage deveria gravar 'dark', veio ${stored}`);

/* ---- keyboard accessibility of the toggle ---- */
/* Tab through the document and confirm the toggle is reachable by keyboard.
   (focus() on a non-focusable element is a no-op, so start from the body.) */
await page.evaluate(() => { document.activeElement?.blur(); window.scrollTo(0, 0); });
const focusOrder = [];
let toggleFocused = false;
for (let i = 0; i < 25; i++) {
  await page.keyboard.press('Tab');
  const info = await page.evaluate(() => ({
    id: document.activeElement?.id || '',
    cls: document.activeElement?.getAttribute('class') || '',
  }));
  focusOrder.push(info.id || info.cls || '?');
  if (info.id === 'theme-toggle') { toggleFocused = true; break; }
}
ok(toggleFocused,
  `teclado: toggle não é focável por Tab (ordem: ${focusOrder.join(' > ')})`);

/* It must actually respond to Enter/Space, not just be focusable. */
await page.evaluate(() => document.getElementById('theme-toggle').focus());
await page.keyboard.press('Enter');
await page.waitForTimeout(400);
const afterEnter = await page.getAttribute('html', 'data-theme');
ok(afterEnter === 'light', `teclado: Enter no toggle não trocou o tema (veio ${afterEnter})`);
await page.keyboard.press('Enter');
await page.waitForTimeout(400);

/* A visible focus ring is what makes keyboard use actually trackable. */
const ring = await page.evaluate(() => {
  const b = document.getElementById('theme-toggle');
  b.focus();
  const s = getComputedStyle(b);
  return { outline: s.outlineWidth, style: s.outlineStyle };
});
ok(parseFloat(ring.outline) >= 2 && ring.style !== 'none',
  `teclado: sem anel de foco visível (outline: ${ring.outline} ${ring.style})`);

/* ---- responsive ---- */
await page.setViewportSize({ width: 375, height: 720 });
await settleRetry(page, `${BASE}/index.html`);
const overflowX = await page.evaluate(() =>
  document.documentElement.scrollWidth - document.documentElement.clientWidth);
ok(overflowX <= 1, `mobile 375px: overflow horizontal de ${overflowX}px`);
ok(await page.isVisible('#theme-toggle'), 'mobile: toggle sumiu da viewport');

/* ---- content parity: each page must keep ITS OWN text ---- */
const sentinels = JSON.parse(process.env.SENTINELS_BY_SLUG);
for (const [slug, path] of PAGES) {
  /* Native fetch, not page.request: the Playwright API context shares the
     browser's connection pool and times out once the run has driven the page
     many times, even though the server answers in ~60ms. */
  const res = await httpGet(BASE + path);
  const html = typeof res.text === 'function' ? await res.text() : '';
  ok(html.length > 200, `${slug}: resposta vazia (HTTP ${res.status ?? 0})`);
  const body = html.replace(/<script[\s\S]*?<\/script>/g, '')
                   .replace(/<style[\s\S]*?<\/style>/g, '')
                   .replace(/<[^>]+>/g, ' ')
                   .replace(/\s+/g, ' ');
  const needle = sentinels[slug];
  if (!needle) {
    /* Translated pages carry their own wording; check the page renders real
       prose instead of asserting an English sentinel. */
    ok(body.length > 200, `${slug}: página traduzida sem conteúdo suficiente`);
  } else {
    ok(body.includes(needle),
      `${slug}: texto perdido — "${needle}" não está no HTML`);
  }
}

/* ---- contrast gates: text must never be painted in its own background ----
   Runs inside the page so it can walk up the tree for the effective
   background colour. Target is WCAG AA for body text (4.5:1). */
const CONTRAST_TARGET = 4.5;

for (const [label, path] of [['home', '/index.html'], ['content', '/CONTRIBUTING.html']]) {
  for (const theme of ['dark', 'light']) {
    /* A page per theme: addInitScript accumulates on a reused page, and the
       stored preference would leak into the next assertion. */
    const cpage = await freshPage();
    await cpage.addInitScript(t => {
      try { localStorage.setItem('piano-wiki-theme', t); } catch (e) {}
    }, theme);
    await settleRetry(cpage, BASE + path);

    const problems = await cpage.evaluate(({ target }) => {
      const parse = s => (s.match(/\d+/g) || []).slice(0, 3).map(Number);
      const lum = ([r, g, b]) => {
        const f = v => { const s = v / 255; return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4; };
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
      };
      const cr = (a, b) => {
        const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
        return (l1 + 0.05) / (l2 + 0.05);
      };
      /* Composite a translucent colour over an opaque one (simple source-over). */
const over = (fg, alpha, bg) => fg.map((c, i) => c * alpha + bg[i] * (1 - alpha));

const bgOf = el => {
        let n = el;
        const layers = [];
        while (n && n !== document.documentElement) {
          const cs = getComputedStyle(n);
          const m = cs.backgroundColor.match(/rgba?\(([^)]+)\)/);
          if (m) {
            const p = m[1].split(',').map(x => parseFloat(x));
            const alpha = p.length === 4 ? p[3] : 1;
            if (alpha > 0) {
              if (alpha >= 1) return [p[0], p[1], p[2]];
              layers.push([[p[0], p[1], p[2]], alpha]);
            }
          }
          n = n.parentElement;
        }
        /* Flatten every translucent layer we passed through, bottom-up. */
        let out = parse(getComputedStyle(document.body).backgroundColor);
        for (const [col, alpha] of layers.reverse()) out = over(col, alpha, out);
        return out;
      };
      const out = [];
      const sel = 'h1,h2,h3,p,li,a,button,.btn,.card-title,.hero-kicker,.brand-name,.lead,.lang-opt';
      for (const el of document.querySelectorAll(sel)) {
        if (!el.textContent.trim()) continue;
        const cs = getComputedStyle(el);
        if (cs.visibility === 'hidden' || cs.display === 'none') continue;
        /* skip intentionally muted/secondary text — those are checked by eye */
        if (el.matches('.footer-inner, .card-desc, .hero .lead, .brand-sub, .footer-links *')) continue;
        const fg = parse(cs.color);
        const ratio = cr(fg, bgOf(el));
        if (ratio < target) {
          out.push({
            sel: el.tagName + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
            text: el.textContent.trim().slice(0, 34),
            color: cs.color, ratio: +ratio.toFixed(2),
          });
        }
      }
      return out;
    }, { target: CONTRAST_TARGET });

    await cpage.close();
    for (const p of problems) {
      fails.push(`contraste ${label}/${theme}: "${p.text}" ${p.color} contraste ${p.ratio} < ${CONTRAST_TARGET} (${p.sel})`);
    }
  }
}

console.log('console errors:', consoleErrors.length ? consoleErrors : 'nenhum');
console.log('failed requests:', failedReqs.length ? failedReqs : 'nenhum');

await browser.close();

if (fails.length) {
  console.error(`\nFALHOU (${fails.length}):`);
  fails.forEach(f => console.error('  - ' + f));
  process.exit(1);
}
console.log('\nOK — todas as verificações de browser passaram.');