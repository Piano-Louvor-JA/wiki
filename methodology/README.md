# Metodologia PIANO — Conhecimento Público

> Documentação extraída e sanitizada da biblioteca de desenvolvimento do Rafael.
> Aplica-se a **qualquer stack/agente** (Claude Code, Codex, Cursor, Gemini, etc.).
> Não requer Hermes — é conhecimento universal.

---

## 📚 Núcleo (Core Methodology)

| Documento | Descrição |
|-----------|-----------|
| [Project Excellence](core/project-excellence.md) | Qualidade, CI, DORA, OSS Excellence, Release governance |
| [Rafael Workflow](core/rafael-workflow.md) | Ciclo SDD → Kanban Hermes → Gauntlet → Release |
| [Spec-Driven Development](core/spec-driven-development.md) | SPEC → PLAN → Tasks → Verify (EARS, BD-XX, RF-ID) |
| [Writing Plans](core/writing-plans.md) | PLAN.md com fases shippable, tasks atômicas, estimativa em horas |
| [QA Agent — 7 Gates](core/qa-agent.md) | Gatekeeper: spec compliance, mutation, lighthouse, LGPD, rastreabilidade RF-ID |
| [Test-Driven Development](core/test-driven-development.md) | RED-GREEN-REFACTOR, testes antes do código, coverage 100% + mutation |
| [GitHub Code Review](core/github-code-review.md) | Security scan, quality gates, auto-fix, review checklist |
| [Subagent-Driven Development](core/subagent-driven-development.md) | Delegação de tasks para subagents com contexto isolado |
| [GitHub PR Workflow](core/github-pr-workflow.md) | Branch flow, PR checks, merge strategies, staging→main |
| [Requesting Code Review](core/requesting-code-review.md) | Pre-commit review, security scan, quality gates, auto-fix |
| [Stryker Mutation Testing](core/stryker-mutation-testing.md) | Mutation score, config, thresholds, CI integration |
| [Vitest Coverage Workflow](core/vitest-coverage-workflow.md) | 100% coverage, v8 provider, thresholds, CI gates |
| [Playwright E2E Testing](core/playwright-e2e-testing.md) | Auth mocking, page.route, CI config, visual regression |
| [Regression Guard](core/regression-guard.md) | Consumers analysis, 4-layer gate, pre-edit checks |
| [Regression Gate 4-Layer](core/regression-gate-4layer.md) | 4-layer regression gate implementation |
| [Test Quality Patterns](core/test-quality-patterns.md) | Coverage 100% + mutation score via Stryker/Vitest |
| [Mutation Testing Patterns](core/mutation-testing-patterns.md) | Stryker config, thresholds, CI integration |
| [Systematic Debugging](core/systematic-debugging.md) | 4-phase root cause debugging |

---

## 🎯 Domain Skills (Ecossistema PIANO)

| Documento | Descrição |
|-----------|-----------|
| [Pianolouvorja App Electron](domain/pianolouvorja-app-electron.md) | Arquitetura desktop, DevTools, pitfalls de build |
| [Pianolouvorja App Electron Workflow](domain/pianolouvorja-app-electron-workflow.md) | Ciclo: branch, teste, PR, release multi-plataforma |
| [LouvorJA Module Development](domain/louvorja-module-development.md) | Como criar módulos (liturgia, hinos, bíblia) |
| [Pianolouvorja UI Patterns](domain/pianolouvorja-ui-patterns.md) | Design system, botões com borda/fundo, AppConfirm |
| [Pianolouvorja Stage Customization](domain/pianolouvorja-stage-customization.md) | Personalização do Palco (StageSettings) |
| [Palco Multi-Screen](domain/palco-multi-screen.md) | Arquitetura multi-tela e cast para TV |
| [Pianolouvorja Palco Cast](domain/pianolouvorja-palco-cast.md) | Arquitetura multi-tela e cast para TV |
| [Pianolouvorja Web Repo Workflow](domain/pianolouvorja-web-repo-workflow.md) | Repo, CI, release, PWA |
| [Pianolouvorja Web Feature Patterns](domain/pianolouvorja-web-feature-patterns.md) | Padrões de implementação de features no web |
| [Pianolouvorja Site Patterns](domain/pianolouvorja-site-patterns.md) | Padrões do site (Nuxt 3) |
| [Pianolouvorja Mobile Release Workflow](domain/pianolouvorja-mobile-release-workflow.md) | Qualidade, versionamento, PR, release (semver fases) |
| [LouvorJA API](domain/louvorja-api.md) | API oficial do LouvorJA (upstream) |
| [Pianolouvorja API](domain/pianolouvorja-api.md) | Hono + Zod OpenAPI + SQLite, contratos _db, rotas /v1/custom |
| [LouvorJA Delphi Interop](domain/louvorja-delphi-interop.md) | Formatos de dados do Delphi original |
| [LouvorJA .ja Liturgy](domain/louvorja-ja-liturgy.md) | Spec do formato .ja (liturgia) |
| [LouvorJA Remote Pairing](domain/louvorja-remote-pairing.md) | Pareamento/controle remoto entre dispositivos |
| [WT5 Palco Cloud](domain/wt5-palco-cloud.md) | TVs/receivers via relay cloud |

---

## Como usar

1. **Dev humano**: leia `AGENTS.md` primeiro → escolha skill de domínio → siga templates SDD
2. **Agente IA**: leia `llms.txt` (mapa machine-readable) → carregue skill relevante → execute task
3. **Feature nova**: SPEC.md (EARS/BD-XX) → PLAN.md (fases shippable) → Tasks → Verify (QA 7 Gates)

---

## Princípios universais

- **Paridade**: web ↔ app ↔ APK (mesmos contratos API, não mesmo código)
- **TV = dumb display** via WebSocket próprio (não Chromecast)
- **Testes com música SACRA IASD** (Athus, Vox, Arautos) — nunca mundana
- **SDD**: SPEC → PLAN → Tasks → Verify (QA 7 Gates)
- **RF-ID obrigatório**: rastreabilidade spec → código → teste → commit
- **Qualidade**: coverage 100% + mutation testing (Stryker) + Lighthouse + LGPD
