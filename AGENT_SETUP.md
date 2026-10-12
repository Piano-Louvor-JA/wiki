# Piano LouvorJA — setup for coding agents

This is the public setup guide for coding agents working on **Piano LouvorJA**
(`Piano-Louvor-JA` on GitHub): an app ecosystem for church hymns at the piano.

One API serves three clients (desktop Electron, mobile Flutter APK, web PWA),
plus a landing site. Everything is built and reviewed with AI agents alongside
humans — this page is meant to get you productive without asking anyone anything.

Internal project documentation is the source of truth for internal decisions and
is not public. This page is a map of the public conventions, not a substitute
for a repository's own instructions.

## Read the repository instructions first

Each repository carries its own `AGENTS.md` or equivalent. **If it exists, it
overrides this page.** Read it before writing code in that repository.

In this wiki:

- [Getting started](GETTING_STARTED.md) — the contribution flow
- [Architecture](ARCHITECTURE.md) — the product ecosystem and design principles
- [Contributing](CONTRIBUTING.md) — expected change shape and pull request checklist
- [Agent guide](AGENTS.md) — the rules for agents working with this repository

Do not guess a port, an environment variable name, or a review rule. Read the
document.

## Repositories and what they serve

| Repository | Stack | Serves |
|---|---|---|
| `api` | Hono + Zod OpenAPI + SQLite | the single backend — all clients consume it |
| `app` | Vue 3 + Electron | desktop (Windows/Mac/Linux) |
| `web` | Vue 3 + Vite + PWA | browser |
| `apk` | Flutter | Android/iOS |
| `site` | Nuxt | landing and public pages |
| `palco-receiver` | JS/HTML (TV targets) | screen projection on webOS/AndroidTV/Tizen |

Changing an API contract affects every client at once. Announce it in the pull
request and update the consumers in the same change.

## Non-negotiable rules

These apply to contributions to this organization. A repository's own
`AGENTS.md` or contribution guide takes precedence over this page.

- **Check the repository's contribution guide before opening a pull request.**
  Branch targets differ by repository, and this page does not describe them
  authoritatively. Opening a pull request against the wrong branch is the most
  common way a contribution gets stalled.
- **Conventional Commits** (`feat:`, `fix:`, `chore:`) where the repository
  follows them. Match the repository, not this page.
- **Gates run before you push**: lint, typecheck, tests and build, as documented
  in the repository. A red build on the remote is a broken branch.
- **Offline-first is a product invariant** on the desktop, mobile and web
  clients. Downloads and progress must survive reload, background and updates.
  If a change touches persistence, write the roundtrip test (save → reload →
  assert) in the same commit.
- **API middleware is log-only**: telemetry and rate limiting never block real
  traffic unless the user agent is unambiguously a bot.
- **If the repository requires signed commits**, they are signed. Hooks are part
  of the setup — run them normally, and use `--no-verify` only after the hook
  itself fails, saying so when you do.

## Traps that are expensive to discover on your own

These are conventions of the ecosystem, not deployment specifics.

- **Base URLs travel through build-time defines** on the mobile client — never
  hardcode them. Without the defines the app builds fine and fails at runtime.
- **Config persistence needs the roundtrip test**: a new persisted field must be
  added to the normalizer whitelist in the same commit, otherwise it silently
  vanishes on first reload. An empty list is valid state; a normalizer that
  collapses an empty list into defaults resurrects deleted data.
- **Blob URLs must pass through resolvers untouched.** Prefixing `blob:` with the
  API base produces a malformed URL and a silent playback failure.
- **Split large changes.** A focused pull request is easier to review than a
  large one, and easier to revert.
- **Match the runtime version the repository expects.** A mismatch gives wrong
  test results.
- **Use appropriate test media.** For the projection and playback paths, use
  public-domain or licensed content only.

## Review

Contributions are reviewed before they land, and a human approves on top.
Automated review never merges on its own.

When a reviewer asks for changes, read what they asked for, split the work if it
is too large to review clearly, and push again. Reviewers are the authority on
what a change needs — not this page.

## Elsewhere

- Production: https://pianolouvorja.com.br
- Organization: https://github.com/Piano-Louvor-JA

Internal decisions, active plans, ADRs, board automation, infrastructure
addresses, deployment configuration and credentials stay private. If a page here
may expose sensitive information, remove it immediately and notify maintainers
through a private channel.