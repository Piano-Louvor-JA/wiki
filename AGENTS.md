# AGENTS.md — Piano LouvorJA

Public guidance for contributors and coding agents.

## Repositories

| Repository | Stack | Responsibility |
|---|---|---|
| [app](https://github.com/Piano-Louvor-JA/app) | Electron, Vue, Vuetify | Native desktop reference implementation |
| [web](https://github.com/Piano-Louvor-JA/web) | Vue, Vuetify, Vite PWA | Browser experience |
| [api](https://github.com/Piano-Louvor-JA/api) | Hono, Zod OpenAPI, SQLite | Shared public contracts and services |
| [apk](https://github.com/Piano-Louvor-JA/apk) | Flutter | Offline-first mobile companion |
| [site](https://github.com/Piano-Louvor-JA/site) | Nuxt | Public website and end-user docs |
| [palco-receiver](https://github.com/Piano-Louvor-JA/palco-receiver) | HTML/JS | TV receiver and display client |
| [palco-updates](https://github.com/Piano-Louvor-JA/palco-updates) | GitHub Pages | Receiver update channel |

## Non-negotiable rules

- Read the target repository's `AGENTS.md`, README and relevant tests first.
- Use a focused `feat/*`, `fix/*`, `docs/*` or `chore/*` branch. Open PRs against `staging`; releases flow `staging` to `main`.
- Keep commits atomic and conventional.
- Test real code. Do not replace behavior with a reimplementation in a test.
- Preserve contract parity across desktop, web and mobile. Share API contracts, not UI code.
- Ask for a decision when a store account, credential, architecture or public contract is required.

## Never do this

1. Commit credentials, tokens, `.env` files, personal data, private URLs, server addresses or production paths.
2. Mix unrelated formatting with a feature.
3. Discard work with `git checkout -- .` before reviewing `git status`.
4. Test Electron only through a browser; validate the Electron application window.
5. Use browser-native blocking confirmation dialogs when the app provides its own confirmation component.
6. Propose Chromecast or AirPlay as part of the TV architecture. Receivers use the project WebSocket protocol.
7. Assume a database migration completed after deployment; verify the intended schema and health checks.
8. Put runtime resources under ignore rules that exclude them from desktop packaging.

## Agent workflow

1. Baseline audit: inspect code, scripts and tests before writing a spec.
2. For non-trivial work: SPECIFY, PLAN, IMPLEMENT, VERIFY.
3. Start with a failing behavior test when changing behavior.
4. Run the repository's lint, type-check, tests and build before opening a PR.
5. Include validation evidence and affected consumers in the PR.

Read [agentic-dev/prompts.md](agentic-dev/prompts.md) for the working patterns.
