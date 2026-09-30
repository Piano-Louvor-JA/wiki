# Piano LouvorJA — Wiki de Desenvolvimento

> Onboarding público para desenvolvedores e agentes de IA do ecossistema
> **PIANO** — sistema de apoio a cultos (liturgia, hinos, bíblia, cronômetros
> e projeção multi-tela) para desktop, web, mobile e TV.

**📖 Documentação online:** https://piano-louvor-ja.github.io/wiki/

---

## Comece aqui

1. [AGENTS.md](AGENTS.md) — convenções, stack e regras "NUNCA faça"
2. [Getting Started](getting-started/README.md) — rodar cada projeto local
3. [Arquitetura](architecture/overview.md) — visão multi-device

## Desenvolvimento

- [Git, Branches e PRs](workflows/git-and-prs.md)
- [Releases](workflows/releases.md)
- [Desenvolvimento Agêntico](methodology/README.md) — skills de domínio, prompts e templates SDD
- [ADRs](adr/) — decisões de arquitetura
- [Permissões](PERMISSIONS.md) — o que você resolve sozinho e o que requer admin

## Para agentes de IA

Mapa machine-readable: [llms.txt](llms.txt)

## Repositórios

| Repo | O que é |
|------|---------|
| [app](https://github.com/Piano-Louvor-JA/app) | Desktop Electron — fonte de referência |
| [web](https://github.com/Piano-Louvor-JA/web) | PWA navegador |
| [api](https://github.com/Piano-Louvor-JA/api) | REST API (Hono + SQLite) |
| [apk](https://github.com/Piano-Louvor-JA/apk) | Mobile Flutter offline-first |
| [site](https://github.com/Piano-Louvor-JA/site) | Site institucional |
| [palco-receiver](https://github.com/Piano-Louvor-JA/palco-receiver) | TVs (webOS/Tizen/AndroidTV) |
| [palco-updates](https://github.com/Piano-Louvor-JA/palco-updates) | Auto-update das TVs |

---

> **Fonte da verdade interna:** `Piano-Louvor-JA/docs` (privado). Esta wiki é a superfície pública sanitizada.
