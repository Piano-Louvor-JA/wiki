# Project Excellence

> **Metodologia pública** — qualidade, CI, DORA, OSS Excellence, Release governance. Aplica-se a qualquer stack/agente.

---
**Solo dev, Next.js/Supabase, projects with money/PII.** Spec-Driven Development with mandatory quality gates. Detailed content lives in `references/` — loaded on demand.


## ABSOLUTE RULES (Non-Negotiable)

| Rule | Description | Gate |
|------|-------------|------|
| #1 | No code without spec. 1 spec = max 200 LOC = 1 subagent | Spec Review |
| #2 | Red CI = no merge. Zero tolerance for failing tests | CI Pipeline |
| #3 | 100% coverage (lines, branches, functions, statements) — v8 provider | Coverage |
| #4 | TypeScript strict + `noUncheckedIndexedAccess` — no `any`, no `!` | Typecheck |
| #5 | Security: RLS, REVOKE PUBLIC, middleware auth, no IDOR, CSP headers | Pentest |
| #6 | Error budget exhausted = feature freeze. Monthly review | SLO Review |
| #7 | Document DURING work, not after. If not in Obsidian, it doesn't exist | Obsidian |

---

## SPEC — Planning + Decomposition

**Structure:** `.planning/<feature>/README.md` + `.planning/<feature>/specs/TASK-*.md`

**Template:** `references/spec-template.md`

**Spec Validation Loop:** Before implementing ANY spec, diff against real project state (DB schema, routes, types). If spec proposes creating existing things, send back to refinement. back for refinement. (See `pitfall SPEC-02`)

---

## SECURITY — OWASP 2025 + Agent Security + Supply Chain

**Top 5 Critical:** SEC-01 (RLS circular), SEC-02 (REVOKE PUBLIC), SEC-03 (middleware auth), SEC-04 (open redirect), SEC-05 (IDOR)

**Full Checklist:** `references/security-checklist.md` (25 items)

**Agent Security (OWASP ASI Top 10):** `references/ai-agent-governance.md`

**Pentest Framework:** `references/pentest-framework.md` — parallel 3-subagent pattern (DB/RLS, Auth/API, Frontend)

---

## Shipd/Olympus: quality gates without exceptions

For Shipd/Olympus validation, `STALE` only means results need refreshing; it never permits ignoring warnings. The completion criterion is **0 BLOCK, 0 FAIL, 0 WARN** plus current evidence for every required gate. Before any portal re-run, synchronize all related artifacts together (prompt, test patch, solution patch, Dockerfile) to avoid mixed-state results. For base/new test-runner contracts, nonce-scoped tests, prompt redundancy, and local validator regression rules, follow `references/shipd-zero-warning-validation.md`.

## CI — Pipelines + Gates

**Unified Template:** `references/ci-template-unified.yml` (Next.js + Supabase, ARM64 self-hosted)

**Gates (all blocking):**
1. Spec Review
2. Lint (Biome) + Typecheck (tsc -b)
3. Unit/Integration Tests (100% coverage v8)
4. Regression Suite (consumidores da matriz de impacto — Regression Guard)
5. Stryker Mutation (threshold 100%)
6. Build
7. Security Scan (npm audit + license)

**Pitfalls:** `pitfalls-all.md` section CI (CI-01 to CI-18) — Husky v10+, Biome 2.x, Knip, branch protection bypass (CI-09)

---

## TESTING — Pyramid 2026 (atualizada 27/09)

| Layer | Tool | Target | Gate | Quando roda |
|-------|------|--------|------|-------------|
| Fast lane | lint + typecheck + unit dos módulos tocados | < 10 min total | Blocking | Todo commit/PR |
| Unit | Vitest | 100% all metrics | Blocking | Todo commit/PR |
| Contract | Zod schemas + snapshot de payload | API ↔ Client + formato entre módulos | Blocking | Todo PR |
| Integration | Vitest + Testcontainers | API routes, DB real | Blocking | Todo PR |
| E2E | Playwright | Só golden paths (≤ 10 jornadas críticas) | Advisory + nightly | Pre-merge + nightly |
| Visual | Playwright toHaveScreenshot (baseline versionado) | Design system + telas críticas | Blocking com revisão de baseline | PR com UI |
| Mutation | Stryker | 100% kill rate | Blocking | PR de módulo crítico |

**Heurísticas 2026 (pyramid ≠ dogma):**
1. Pegar cada bug no menor nível onde reproduz de forma confiável (rounding → unit; formato → contract; "carrinho some no logout" → E2E).
2. E2E que falha por motivo que API test pegaria → reescrever pra baixo e DELETAR o original (nunca deixar os dois).
3. Middle vazio (hourglass) é o pior anti-padrão: bugs de fronteira passam batido com tudo verde. Contract + integration > E2E em custo/benefício.
4. AI agent gera 50 testes E2E em 1 hora — o custo é MANTER por anos. Contar custo de ciclo de vida, não de criação.
5. Distribuição depende da arquitetura: monolith = mais unit; serviços = contract/integration dominam. A pirâmide é consequência, não meta.

**Coverage Strategy:** `references/testing-coverage.md` — dead code removal FIRST, then honest exclusions, then targeted tests. NEVER exclude source files to inflate %.

**Pitfalls:** `pitfalls-all.md` section TEST (TEST-01 to TEST-23)

---

## RELIABILITY — SLOs + Error Budget + PRR + Rollback

**SLOs:** Availability 99.9%, Latency p95 < 500ms, Error Rate < 0.1%

**Error Budget:** 4-week rolling window. Budget exhausted = feature freeze.

**PRR (Production Readiness Review):** `references/reliability-patterns.md` — checklist before any release

**Rollback:** `< 5 min` via `gh release delete` + tag rollback + DB migration down

**Postmortem:** Blameless, within 48h, action items tracked in Obsidian

---

## OPS — DORA 2025 + Feature Flags + Observability

**DORA Targets:** Lead Time < 1 day, Deploy Freq on-demand, MTTR < 1 hour, Change Fail Rate < 15%

**Feature Flags:** LaunchDarkly-style local (Next.js middleware + cookies)

**Observability:** OTel + Loki + Tempo (self-hosted) or Vercel Analytics

**Full Playbook:** `references/ops-playbook.md`

---

## AI AGENT GOVERNANCE

**OWASP ASI Top 10 Mapping:** `references/ai-agent-governance.md`

**Subagent Protocol:**
- Leaf agents only (no nesting)
- Max 2 parallel for code tasks
- Context: file paths, error messages, constraints
- Verify outputs: URLs, file paths, HTTP status — never trust "success" claims

**Cost/Token Budget Guardrails:** `references/cost-budget-guardrails.md` — per-feature limits, reviewer model selection, self-consistency 3x guard

---

## SOLO DEV PLAYBOOK

**Self-Review Checklist:** `references/solo-dev-playbook.md`

**Cognitive Load Management:** One spec at a time, commit after each green gate

**Anti-Patterns:** Ignoring failing tests, skipping Spec Validation Loop, trusting user state

---

## PWA — Progressive Web App Checklist

**Full Checklist:** `references/pwa-checklist.md` — manifest, SW, offline, install prompt, iOS Safari quirks

---

## OSS CONTRIBUTION ORCHESTRATION

**Context-Aware Hub:** `references/oss-contribution.md` — CodeRabbit compliance, AI policy checks, progress tracking

---

## MULTI-PROJECT WORKFLOW (Solo Dev)

**Pattern:** `references/multi-project-workflow.md` — shared configs, monorepo vs polyrepo tradeoffs, context switching

---

## SETUP — New Project Quick Reference

```bash
# 1. Init
npx create-next-app@latest --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
npm i -D vitest @vitest/coverage-v8 @vitest/ui playwright @playwright/test stryker msw zod

# 2. Configs (copy from references/)
cp references/biome.json biome.json
cp references/vitest.config.ts vitest.config.ts
cp references/tsconfig.json tsconfig.json
cp references/ci-template-unified.yml .github/workflows/ci.yml
cp references/husky-pre-commit .husky/pre-commit
cp references/husky-pre-push .husky/pre-push

# 3. DB
# Supabase local: npx supabase start
# Migrations: supabase/migrations/
# RLS policies: see security-checklist.md SEC-01, SEC-02
```

---

## PITFALLS — Categorized & Numbered

**Full List (91 items):** `references/pitfalls-all.md`

| Category | Prefix | Count |
|----------|--------|-------|
| Security | SEC-XX | 19 |
| CI/CD & Tooling | CI-XX | 18 |
| Testing & Quality | TEST-XX | 22 |
| Architecture | ARCH-XX | 10 |
| Operations | OPS-XX | 10 |
| Spec & Planning | SPEC-XX | 10 |
| Performance | PERF-XX | 10 |
| Accessibility | A11Y-XX | 8 |

**Top 25 Inline:** See `references/pitfalls-top25.md` for quick reference

---

## CROSS-REFERENCE

| Topic | Reference |
|-------|-----------|
| Vercel Deployment Notifications | `references/vercel-deployment-notifications.md` |
| Coverage Provider Bugs (v8 vs istanbul) | `test-driven-development` skill → `references/vitest-coverage-providers.md` |
| Project State Analysis for MVP | `references/project-state-analysis-for-mvp.md` |
| AI Agent Security (OWASP ASI Top 10) | `references/ai-agent-governance.md` |
| Solo Dev Playbook | `references/solo-dev-playbook.md` |
| Vue 3 + Vite + Vitest Setup | `references/vue3-vite-vitest-setup.md` |
| Vue 3 + Vite + ESLint v9 Security | `references/vue3-vite-eslint-v9-security-patterns.md` |
| Spec-Driven Development (Thoughtworks 2025) | Context engineering, spec as compression, deterministic CI/CD |
| DORA 2025 | AI = amplifier. AI Quality Metrics: Pass Rate ≥ 70%, Regression Rate < 20%, Spec Accuracy ≥ 80% |
| Error Budget Policy | Google SRE Workbook adapted for solo dev. 4-week rolling. Budget exhausted = feature freeze. Monthly review. |
| Cost/Token Budget Guardrails | `references/cost-budget-guardrails.md` |
| Master Definition of Done | `references/master-dod.md` |
| Dependency Policy (Renovate/Dependabot + Flaky Tests) | `references/dependency-policy.md` |
| Deprecation Policy (RF-IDs/Zod Schemas) | `references/deprecation-policy.md` |
| WCAG AA Accessibility Criteria | `references/wcag-aa-criteria.md` |

---

## VERSION HISTORY

- **v9.8.0** (2026-07-23): BUG 1/2/3 fixed (corrupted ASCII removed, frontmatter cleaned, pitfalls categorical renumbering). Architecture restructured to lean index (~200 lines). Content gaps added (cost budget, master DoD, dep policy, deprecation policy, WCAG AA). All references synchronized.
- **v9.7.0**: Original monolithic version (1797 lines, 101KB)