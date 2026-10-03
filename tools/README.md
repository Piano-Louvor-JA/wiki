# tools — local preview and verification

These scripts are **not part of the published site**. They exist so the wiki can
be inspected and gated locally before any push. GitHub Pages renders the site
with its own Jekyll 3.10; nothing here runs in the build.

## Why a local preview at all

The publication contract is frozen: GitHub Pages, branch `main`, path `/`,
build type `legacy`, **no GitHub Actions** (see
`WIKI-PUBLICA-BRANCH-BASED.md`). That means there is no CI job to catch a broken
layout before it goes live — so the gates live here instead.

## Requirements

    gem install kramdown kramdown-parser-gfm rouge liquid
    node --experimental-strip-types  # or plain node >= 20

## Run

    # 1. render the 9 allowlisted pages with the same engines Pages uses
    ruby tools/preview.rb /tmp/wikiroot/wiki

    # 2. serve them under the /wiki prefix Pages uses
    python3 -m http.server 8900 --directory /tmp/wikiroot

    # 3. run the gates (needs the server on :8900)
    SENTINELS_BY_SLUG="$(ruby tools/content_sentinels.rb)" \
      node tools/verify-preview.mjs

    # optional: capture screenshots
    node tools/screenshots.mjs /tmp/wiki-shots

## What the gates check

`preview.rb`
  - one `<h1>` per page
  - header, footer, logo and stylesheet present
  - no unrendered Liquid left in the output
  - every internal link resolves to a built file
  - every referenced asset exists

`verify-preview.mjs` (real browser)
  - dark is the default; toggle flips and persists across navigation
  - no flash of wrong theme on load
  - Inter actually loads (not a fallback font)
  - nav links all return 200
  - keyboard: the toggle is reachable by Tab and responds to Enter
  - mobile 375px: no horizontal overflow
  - **content parity**: one sentinel per page, taken from the markdown source,
    must survive into the HTML
  - **contrast**: every heading, link, button and paragraph clears WCAG AA
    (4.5:1) in both themes

`content_sentinels.rb`
  - emits the per-page sentinel
  - fails if the markdown allowlist ever drifts from 9 files

`escape_placeholders.rb`
  - `<placeholder>` in the templates is parsed by kramdown as a raw HTML tag,
    which deletes the text from the rendered page (a bug that already exists on
    the live site). `--check` fails if any raw placeholder reappears.

## Caveat

The preview approximates two things Pages does natively: `jekyll-seo-tag`
(stubbed in `preview.rb`) and anchor-js heading links (emitted at build time).
Everything else — layout, CSS, markdown parsing — is the real thing.
