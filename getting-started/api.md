# Getting Started — api (REST)

> Repo: [pianolouvorja/api](https://github.com/Piano-Louvor-JA/api) · versão
> atual 1.3.x · Hono + Zod OpenAPI + SQLite (better-sqlite3 + Kysely) +
> Vitest + Biome + Docker (Node 22)

REST API que serve hinários (Louvor JA e SDA Hymnal), álbuns, músicas, letras
e Bíblia, com OpenAPI completo. Documentação interativa em `/doc` (Scalar).

> **Nota:** a API é a peça central do ecossistema — web, desktop e APK consomem
> os mesmos contratos. Mudanças de contrato afetam 3 clientes.

## Rodando

```bash
git clone https://github.com/Piano-Louvor-JA/api.git
cd api
npm install
npm run dev          # http://localhost:3000 (ou PORT do .env)
```

Docs da API: `http://localhost:3000/doc`

## Scripts

| Comando | O que faz |
|---------|-----------|
| `npm run dev` | dev com hot reload (tsx watch) |
| `npm run build` | compila TypeScript |
| `npm run start` | roda build compilado |
| `npm run test` | Vitest |
| `npm run test:coverage` | Vitest + coverage |
| `npm run lint` | Biome check |
| `npm run validate:pr` | **lint + typecheck + testes — rode antes de abrir PR** |
| `npm run import:upstream` | importa catálogo upstream |
| `npm run import:sda` | importa SDA Hymnal |

## Variáveis de ambiente (`.env`)

| Var | Default dev |
|-----|-------------|
| `NODE_ENV` | `development` |
| `DB_PATH` | `./data/catalog.db` |
| `MEDIA_DIR` | `./media` |
| `PORT` | `3100` |
| `CACHE_TTL_HYMN` / `_AUDIO` / `_BIBLE` | TTLs de cache |
| `RATE_LIMIT_PER_MIN` | `100` |
| `CORS_ORIGINS` | `*` (compat com apps) |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | envio de e-mail (reset de senha, boas-vindas) |

## Migrations

- O runner de migrations executa **statement a statement**, tolerando erros
  idempotentes (lição da migration 020/022 — ver ADR futuro).
- Após deploy, **sempre verificar** que a migration rodou completa (o container
  reinicia no boot; 502 transitório de ~30-60s no Caddy é normal).

## Testes com reset de senha

O fluxo de reset pode expor o token com `RESET_TOKEN_EXPOSE=1` para dev local.

## Produção

Hospedada em VPS (Docker + Caddy) — detalhes de deploy ficam com o time de ops.
502 em `/v1/health` logo após deploy é transitório (container reiniciando).

## Onde continuar

- Workflows: [workflows/git-and-prs.md](../workflows/git-and-prs.md) (PRs de
  código base **staging**)
