# AGENTS.md — pianolouvorja/docs

> Guia para agentes de IA e devs trabalhando nos projetos Piano LouvorJA.

## A conta e os repos

`pianolouvorja` é **conta de usuário GitHub** (não org). Repos:

| Repo | Stack | Papel |
|------|-------|-------|
| `app` | Electron + Vue 3 + Vuetify | Desktop (Windows/Linux/macOS), source-of-truth de features |
| `web` | Vue 3 + Vuetify 4 + Vite + PWA | Web / operação no navegador |
| `api` | Hono + Zod OpenAPI + SQLite (Docker) | REST API própria (pianolouvorja.com.br) |
| `apk` | Flutter | App mobile (Android API21+/iOS13+), offline-first |
| `site` | Nuxt 3 SSR | Site institucional + docs de usuário |
| `palco-receiver` | HTML/JS (.ipk/.wgt) | TVs (webOS/Tizen/AndroidTV), dumb display via WS |
| `palco-updates` | GitHub Pages | Canal de auto-update dos receivers |
| `docs` | Markdown + mkdocs | **Este repo**: wiki de dev + hub agêntico |

## Convenções obrigatórias

- **Branch flow:** `feat/*` → PR para **`staging`** → PR staging→main. NUNCA PR direto pra main.
- **Reviews:** Ezequias revisa antes de merge. PR pequena e focada.
- **Commits:** atômicos, convencionais (`docs:`, `feat:`, `fix:`, `ci:`).
- **Paridade:** feature nova precisa ter caminho em web ↔ app ↔ APK (a maioria dos usuários está no celular).
- **API:** repo api NÃO é divulgado publicamente; autoria do conteúdo é Mayco.

## NUNCA faça (pitfalls)

1. NUNCA commitar `.env.local`, tokens, senhas, SMTP_PASS.
2. NUNCA usar `window.confirm` nos apps (usar AppConfirm).
3. NUNCA abrir app Electron no browser — é desktop nativo.
4. NUNCA commitar reformatting de código pré-existente junto com feature.
5. NUNCA `git checkout -- .` sem revisar `git status` antes.
6. NUNCA testar projeção/mídia com música mundana — usar SACRA IASD (Athus, Vox, Arautos).
7. NUNCA assumir que migration rodou no deploy de produção — verificar.
8. Em docs públicos: NUNCA incluir IPs de produção, paths de server, credenciais.
9. Chromecast NÃO existe no projeto — TV conecta ao cliente via WS próprio (StageSession/relay).
10. Electron: arquivos lidos em runtime DEVEM estar fora do .gitignore (electron-builder respeita .gitignore → ENOENT no asar).

## Workflow para agentes

1. Leia `SPEC.md`/`PLAN.md` em `.planning/` antes de tocar em código (SDD).
2. Toda feature grande: SPECIFY → PLAN → IMPLEMENT → VERIFY (skill spec-driven-development).
3. Testes: RED antes de GREEN. Sem testes falsos (exercitar o código real).
4. Antes de push: lint + typecheck + testes + build local (Phase 6 do OSS Excellence).
5. Registros de decisão de arquitetura → `adr/NNN-*.md` neste repo.
