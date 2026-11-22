# Documentation editor

How non-developer volunteers edit the public documentation of the site
without touching a local development environment.

## What it is

The site's documentation lives as markdown files in the repository. A web-based
editor (Decap CMS) is served at `/cms/` and edits exactly those files. The
`/admin/` path remains reserved for the site's operational panel — the editor
is not there.

## How publishing works

The editor runs in the **editorial workflow** mode: saving a page creates or
updates a pull request against the site repository's integration branch. A
maintainer then reviews the change and merges it by hand; the normal deploy
pipeline publishes the documentation afterwards. There is no direct path from
the editor into production.

The flow, end to end:

1. Sign in at `/cms/` with an invited account.
2. Create or edit a page under **Documentação**.
3. Save as draft to continue later.
4. Submit for review when the text is ready.
5. Publish — which opens a pull request, not a deployment.
6. A maintainer reviews and merges manually.

## Editor configuration

- Backend: `git-gateway` (requires the hosting platform's identity service and
  Git Gateway, connected to the site repository).
- Media: uploaded images go to an uploads folder and are referenced publicly.
- No credentials live in the repository's editor config or anywhere in Git.
- Collection schema per documentation page: title, description, navigation
  order, platform, review date, table-of-contents flag, and the markdown body.

## Testing locally

For local development the editor can talk to a local backend (`decap-server`)
with a temporary `local_backend: true` flag in a local copy of the config.
That flag must be removed before publishing — it is development-only.

## Rules for editors

- Write in the language of the page you are editing.
- One topic per page; keep navigation order meaningful.
- Do not paste credentials, private URLs or screenshots of internal systems —
  the same rules that apply to any public contribution apply here.
- Every change still goes through human review; the editor does not bypass it.
