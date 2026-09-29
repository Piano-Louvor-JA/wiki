# Pianolouvorja API

> **Metodologia pública** — Hono + Zod OpenAPI + SQLite, contratos _db, rotas /v1/custom, sistema de arquivos. Aplica-se a qualquer stack.

---
## Identidade

| Campo | Valor |
|-------|-------|
| Repo | github.com/Piano-Louvor-JA/api (a criar no GitHub — local em /home/ubuntu/piano-api) |
| Stack | Node 22 + Hono 4 + SQLite (better-sqlite3) + Kysely |
| Deploy | Docker container (agnostico — Hostinger ou qualquer VPS) |
| Dominio | api.Piano-Louvor-JA.com.br |
| Custo | Zero (VM existente ou Hostinger + Cloudflare free) |

## Modelo de Negocio

- IASD (Hinario Adventista, Louvor JA, Biblia): GRATIS, sem auth
- CCB e outras denominacoes: PAGO, requer X-License-Key header
- Sistema de licencas: tabela licenses com UUID, max_devices, expires_at
- Colaborador: Ezequias (com z, nao Elias) Fonseca — Telegram 1131766246

## Endpoints

### Compatíveis (Drop-in Replacement) — IMPLEMENTADO E TESTADO

A API tem rotas 100% compatíveis com `api.Piano-Louvor-JA.com.br`. Os apps trocam só a URL base e tudo funciona sem mudança de código.

Os apps consomem via:
```
VITE_URL_DATABASE=https://api.louvorja.com.br/json_db  → busca /{filename}
VITE_URL_FILES=https://api.louvorja.com.br/file        → serve midia
```

Nossa API responde nos mesmos formatos:
- `GET /json_db/album_{id}` — JSON cru do album (sem wrapper)
- `GET /json_db/music_{id}` — JSON cru da musica com lyrics array
- `GET /json_db/pt_musics?page=N` — lista paginada {data, meta}
- `GET /json_db/pt_categories` — categorias com albums aninhados
- `GET /json_db/pt_bible_book` / `pt_bible_version` — catalogo biblico
- `GET /json_db/bible_{v}_{b}_{c}` — lazy proxy com cache em disco
- `GET /db/{table}?page=N` — formato Lumen com wrapper {data, meta}
- `GET /file/{path}` — redirect 302 para upstream

Arquivo: `src/routes/compat.ts` — builders constroem JSON no formato exato do upstream.

### Próprios /v1/* (RESTful + Zod OpenAPI) — PARIDADE ALCANÇADA

- GET /v1/health — status da API (OpenAPI)
- GET /v1/musics — lista de músicas paginada, shape idêntico ao pt_musics upstream
- GET /v1/musics/:id — detalhe com lyric[] (estrofes), url_music, url_image, albums[]
- GET /v1/albums — coletâneas paginada
- GET /v1/albums/:id — detalhe com musics[] (track/duration), categories[], color, url_image
- GET /v1/categories — array direto (sem paginação) com albums[] aninhados (color, subtitle, url_image, order)
- GET /v1/bible/:book/:chapter — biblia
- POST /v1/telemetry — ping anonimo
- GET /v1/ccb/hymns — hinos CCB (requer X-License-Key)
- POST /v1/admin/licenses — gerar licenca (Firebase Auth)

Ver `references/php-to-ts-query-translation.md` para as queries SQL exatas traduzidas do PHP.

## Estrategia de Dados (3 camadas)

1. **Proxy cache**: busca de api.Piano-Louvor-JA.com.br, guarda no SQLite. Script de importação completo.
2. **Fontes proprias**: sda-hymnal NPM (695 EN), SacCentral MP3, frazras MIDI. Ainda não integradas.
3. **Midia (audio/imagens)**: **Hostinger 200GB** (nao Cloudflare R2). Script `mirror-media.ts` baixa ~7.6 GB via `/file/*` e espelha na Hostinger. Atualmente redirect pro upstream (fallback planejado: servir da Hostinger com fallback upstream).

### Midia — Mirror para Hostinger (baseline 07/08/2026)

Volume total do upstream (api.louvorja.com.br/file/*):
- 3.491 MP3s (~2.2 MB media cada) = ~7.5 GB
- 1.259 BMPs covers (~57 KB cada) = ~0.07 GB
- **TOTAL: ~7.6 GB** — cabe folgado nos 200 GB da Hostinger

Rate limit do upstream `/file/*`: `x-ratelimit-limit: 10000` por bucket. Com 4.750 arquivos, baixa em 1 batch com margem.

Estrutura na Hostinger:
```
/file/covers/        ← 1.259 BMPs
/file/musics/pt/     ← MP3s portugues
/file/musics/en/     ← MP3s ingles
/file/musics/es/     ← MP3s espanhol
/data/catalog.db     ← SQLite atualizado
```

Mirror: script le tabela `files`, monta path = `dir + "/" + file_name`, baixa via `GET /file/{path}`, salva em disco. Sync incremental via `latest_updated` do `/json_db/config`.

Ver `references/hostinger-media-mirror-strategy.md` para o plano completo de 4 fases.

## Bíblia — Lazy Proxy com Cache (transparente)

15.457 arquivos de versículos no upstream. NÃO importar tudo.
- Catálogo (66 livros + 10 versões) importado no SQLite
- Versículos: lazy proxy transparente — primeira requisição busca do upstream em tempo real, salva em `data/bible_cache/{cacheKey}.json`, e serve. Próximas requisições servem do cache local.
- Cresce organicamente conforme uso
- **IMPORTANTE**: O handler `handleBibleChapter()` deve ser `async` e usar `await fetch(upstreamUrl)`. A rota `/json_db/:file` tambem deve ser `async`. Se retornar erro "Versiculo nao cacheado" o usuario ve tela em branco no modulo biblia.

**Contratos ES + mapeamento completo (10/09/2026)**: `references/bible-catalog-mapping.md` — chave de capítulo `bible_{version}_{book}_{chapter}`, livros ES com offset +66 (ids 67–132), tabela completa das 13 versões (pt 1-9+13, es 10/11/12), gotcha de diagnóstico (mirror local TEM capítulos ES completos; produção do Mayco NÃO tem — 404 em qualquer `bible_10_*`). Endpoints `es_bible_book`/`es_bible_version` implementados no compat.ts (commit `a51c509`; regex `(pt|es)_bible_*` generalizado na PR #78, deployada em produção 12/09/2026). bible_versions agora tem as 3 versões ES. Docs oficiais no repo: `docs/BIBLE_API.md`. GET /v1/bible (REST) semi-quebrado p/ ES e deprecated de facto — apps consomem /json_db. **Importante (12/09/2026)**: o DB de produção já tem 66 livros ES + 3 versões + 93.312 versículos em `bible_book`/`bible_version`/`bible_verse` (`id_language='es'`); após deploy da PR #78 as rotas existem mas podem responder `200 []` (array vazio) se o seed/import ES não rodou no container — apps precisam tratar vazio como fallback PT (pitfall 94).

## Schema SQLite

12 tabelas baseadas no louvorja/api (PHP/Lumen):
languages, files, albums, musics, lyrics, albums_musics, categories, categories_albums, bible_versions, bible_books, bible_verses, ccb_hymns, licenses

Ver: `.planning/SPEC.md` para definição completa.

### Campos críticos da biblia:
- `bible_books`: `id_book`, `name`, `abbreviation` (não `abbrev`!), `chapters`, `book_number`, `id_language`
- O app espera: `id_bible_book`, `abbreviation`, `book_number`, `id_language`

## Importação — IMPLEMENTADO E TESTADO (08/08/2026)

Script `scripts/import-upstream.ts` baixa catálogo completo do upstream com paridade total de dados:

**Dados importados:**
- 5 categorias (com slug, type, order populados)
- 69 albums
- 1889 musicas
- 59.520 estrofes (com id_lyric original do upstream, time, show_slide, order, url_image)
- 4.750 files (com dir, file_name, duration, image_position populados)
- 1.917 albums_musics (com track do pivot do upstream)
- 67 categories_albums (com subtitle/name, order)
- 66 livros biblicos, 10 versões
- SQLite: 6.0 MB, Tempo: ~112s, 0 falhas

**O que o script faz (ordem):**
1. `ensureLanguages()` — pt, en, es
2. `importConfig()` — metadata do catalogo
3. `importCategoriesWithAlbums()` — baixa `/json_db/{lang}_categories` (array cru). Popula slug, type, order em categories; subtitle, order em categories_albums; url_image de cada album via INSERT em files
4. `importMusics()` — baixa `/json_db/{lang}_musics` (array cru, 1889 itens). Popula albums_musics com track do pivot; letra como texto plano
5. `importHymnals()` — baixa `/json_db/{lang}_hymnal` e `_1996`
6. `importAlbumDetails()` — baixa `/json_db/album_{id}` para cada album. Atualiza track de cada musica
7. `importMusicDetails()` — baixa `/json_db/music_{id}` para cada musica. Insere url_music, url_image, url_instrumental_music em files com dir+file_name+duration. Substitui letra simplificada por estrofes detalhadas (com id_lyric, time, instrumental_time, show_slide, order, url_image)
8. `importBible()` — versões e livros (versiculos ficam no lazy proxy)

**Endpoints do upstream (mapeados):**
- `/json_db/{filename}` — retorna JSON cru (sem wrapper). E o formato que os apps consomem.
- `/db/{table}?page=N` — retorna com wrapper Lumen `{data, meta}`. Formato administrativo.
- `/json_db/config` — metadata (version_number, datetime, latest_updated)
- `/json_db/pt_categories` — categorias com albums[] aninhados
- `/json_db/pt_musics` — lista de hinos com lyric (texto plano), albums[] (objetos com id_album)
- `/json_db/music_{id}` — detalhe com lyric[] array, url_music, url_image, albums[]
- `/json_db/album_{id}` — album com musics[] array (id_music, name, track, duration)
- `/json_db/pt_hymnal` / `pt_hymnal_1996` — hinarios (formato simplificado)
- `/json_db/pt_bible_book` / `pt_bible_version` — catalogo biblico

**App Electron consome (mapeado do codigo-fonte em src/shared/services/):**
- `config` → metadata do catalogo (bootstrap)
- `pt_categories` → navegacao principal (categorias + albums aninhados)
- `pt_hymnal` / `pt_hymnal_1996` → lista de hinarios
- `album_{id}` → detalhe do album + musics[] com track/duration
- `music_{id}` → detalhe da musica + lyric[] + url_music + url_image + albums[]
- `/file/{path}` → serve imagens, capas e MP3 (CDN)

## Middleware (planejado)

- **cache**: LRU in-memory com TTL por tipo (letra 24h, audio URL 1h, biblia 7d)
- **rateLimit**: 100 req/min/IP (sliding window)
- **license**: requireLicense(denomination) valida X-License-Key
- **auth**: Firebase Admin verifyIdToken (admin endpoints)

## Deploy

O deploy é AGNÓSTICO. Funciona em qualquer VPS com Docker:
```bash
git clone https://github.com/Piano-Louvor-JA/api.git
cd api
cp .env.example .env
docker compose up -d
```

Na Hostinger: Ezequias gerencia. Opções: Docker, PM2, ou App panel.
Na VM Oracle: Cloudflare Tunnel encaminha localhost:3100.

## Comandos

```bash
npm run dev              # tsx watch (hot reload)
npm run build            # tsc → dist/
npm test                 # Vitest
npm run test:coverage    # Com coverage
npm run import:upstream  # Importa de api.Piano-Louvor-JA.com.br
npm run lint             # Biome check
npm run typecheck        # tsc --noEmit
npm run validate:pr      # biome + tsc + vitest
```

## Config

- `biome.json`: override `noExplicitAny: off` para `test/**` e `src/routes/compat.ts` (builders usam `any` por design)
- Husky: pre-commit (lint-staged), pre-push (tsc + vitest)
- `vitest.config.ts`: projects unit + integration, coverage threshold 40% (subir gradualmente)

## Regras de Ouro

1. Hono, não Express/Nitro. Mais leve, roda em qualquer runtime. Usar `@hono/zod-openapi` para tipagem fim a fim e `@scalar/hono-api-reference` para documentação viva (Scalar em `/doc`, spec em `/openapi.json`). Scalar substituiu `@hono/swagger-ui` (removido) — UI mais rápida, busca melhor, Try-it nativo com fetch.
2. SQLite, não MySQL/Postgres. Um arquivo no disco.
3. Kysely, não Prisma. Type-safe sem overhead.
4. Zod para validação.
5. better-sqlite3 é SINCRONO. Não usar async/await nas queries.
6. CCB requer licença. Endpoints /v1/ccb/* tem middleware requireLicense.
7. Mídia não passa pela API. Cliente faz streaming direto (R2 ou upstream redirect).
8. PT-BR nos comentários. Código/variáveis em inglês.
9. Commits conventional: feat(api):, fix(db):, chore(docker):
10. DDD é overengineering aqui. CRUD de hinários não precisa de domain entities.

## Skills Obrigatórias (6 — sempre carregar)

Antes de qualquer trabalho neste repo, carregar:
1. `software-development/project-excellence` — quality gates, CI/CD, testing
2. `oss-project-excellence` — workflow OSS (LICENSE, CONTRIBUTING, templates)
3. `software-development/spec-driven-development` — SDD (specify → plan → implement → verify)
4. `Piano-Louvor-JA-api` (esta skill) — domain knowledge
5. `Piano-Louvor-JA-ui-patterns` — design system Vue 3 + Vuetify
6. `Piano-Louvor-JA-web-repo-workflow` — CI/CD, branch protection, release

Usar path completo ao carregar (`skill_view(name='software-development/project-excellence')`) para evitar erro de nome ambíguo.

## SDA Hymnal — Feature "Plus" (planejamento 07/08/2026)

O diferencial do `Piano-Louvor-JA/api` vs `louvorja/api`: hinário Adventista em 3 idiomas como feature gratuita adicional.

**Fontes planejadas:**
- NPM `sda-hymnal` — 695 hinos EN (letras)
- SacCentral (bjaarmy.com) — 483/695 MP3 coral EN
- frazras MIDI — 695 arquivos MIDI (GPL)
- PT/ES via `/json_db/music_{id}` do upstream (url_music + url_instrumental_music com sufixo "- PB.mp3")

**Gap atual:** `package.json` tem `"import:sda": "tsx scripts/import-sda-hymnal.ts"` mas o arquivo `scripts/import-sda-hymnal.ts` NÃO existe. É o próximo deliverável.

**Plano de paridade (próximos passos):**
1. Criar `scripts/import-sda-hymnal.ts` — importar 695 hinos EN do NPM `sda-hymnal`
2. Configurar push ao repo GitHub `https://github.com/Piano-Louvor-JA/api.git` (token de colaborador aceito)
3. Criar OSS artifacts (LICENSE, CONTRIBUTING.md, SECURITY.md)
4. Push inicial do repo local → GitHub

## Processo obrigatório para mudanças cross-repo e releases

- Planejar primeiro no Obsidian; registrar decisões, falhas e evidências antes de implementar.
- Todo commit próprio deve usar SSH signing (`commit.gpgsign=true`, `gpg.format=ssh`) e ser conferido com `git log --show-signature` + GitHub `verification.verified=true`.
- Antes do merge, checar PRs de api/app/web/apk: base correta (`feature → staging → main`), conflitos, CI completo e review do codeowner Ezequias. Não burlar branch protection.
- Dependabot deve mirar `staging`; PRs diretas para `main` falham no gate de origem. Configurar `target-branch: staging` em cada repo.
- Validar mudanças cross-front com a mesma resposta real da API: curl no endpoint, mídia (cover/MP3), app Electron real, web e APK. Não confundir console de extensão (`contentscript.js`, ObjectMultiplex) com erro do produto.
- Para formatos legados Delphi, tratar compatibilidade como contrato: estudar serializer/importer em `louvorja/desktop`, capturar fixture real e criar golden round-trip antes de implementar.

## Repos Relacionados

| Repo | Como consome |
|------|-------------|
| Piano-Louvor-JA/app | VITE_URL_DATABASE → /json_db e VITE_URL_FILES → /file |
| Piano-Louvor-JA/web | Mesmo padrão do app |
| Piano-Louvor-JA/mobile | const apiUrl → /v1/* (endpoint próprios) |
| Piano-Louvor-JA/site | Dashboard le /v1/admin/stats |

## Referencias

- Planning: /home/ubuntu/piano-api/.planning/
- SPEC: SPEC.md, PLAN.md, AGENTS.md, CONTEXT.md
- Upstream reference: github.com/louvorja/api (PHP/Lumen)
- **Mapeamento exato de endpoints upstream**: `references/api-upstream-endpoint-mapping.md` — response shapes reais capturados via curl. OBRIGATORIO consultar antes de implementar qualquer rota nova.
- **Tradução PHP → TypeScript das queries**: `references/php-to-ts-query-translation.md` — cada query Eloquent do `DataBase::export_json()` traduzida para better-sqlite3, com diferenças MySQL vs SQLite documentadas. Consultar ao reescrever rotas.
- **Estratégia de mirror de mídia para Hostinger**: `references/hostinger-media-mirror-strategy.md` — volume (~7.6 GB), rate limit do upstream, estrutura de diretórios, design do script `mirror-media.ts`, plano de 4 fases. Consultar ao implementar o mirror.
- **Relay WebSocket do Palco (WT-5a)**: `references/palco-relay-wt5a.md` — arquitetura web+TV sem desktop, endpoints POST /v1/palco/sessions e WS /v1/palco/relay/:code, papéis operator/sender/receiver, gotcha do @hono/node-ws (upgradeWebSocket no app raiz). Consultar ao implementar WT-5b/c/d.
- **Roteamento por slot WT-6A**: receivers declaram `?slot=N`; envelope com `to: slot-N` entrega só no slot; broadcast sem `to` retrocompatível. Web: rota `palco:N` no PopupRouteSelect/popup-windows (NENHUM popup local abre — early-return como rota 'tv'); bridge publica com `to`. Implementado em api `73509ca` + web `adf2004` (04-05/09/2026). Detalhes de validação E2E e incidentes no Obsidian: `04-Projects/PIANO/WT-6-liturgia-tv-e-midias.md`.
- **Replicação de fonte de teste (túnel trycloudflare) nos 3 alvos + cadeia de mídia desktop**: pitfalls 68-77 cobrem a sessão 08/09/2026 — validação E2E do gap Infantis/Doxologia via curl (68), CORP/COOP de túnel Cloudflare bloqueando covers (69) com fixes distintos por plataforma (Electron: strip via onHeadersReceived; web: proxy same-origin no Vite, pitfall 75), API_BASE_URL hardcoded do main-process Electron (71), trackMissing silencioso na Central de Mídia (73), o que replica vs não replica entre app/web/apk (74), e sincronia projeção↔áudio (77). Consultar ANTES de qualquer trabalho de "fonte alternativa no app".

## GOAL: 500 Rounds / 5 Fases (revisado 08/08/2026)

Escopo confirmado pelo usuario: **PARIDADE TOTAL** com louvorja/api — todas as 64 rotas Laravel (auth + admin CRUD + read), mirror midia Hostinger, plus SDA Hymnal.

| Fase | Rounds | Entrega |
|------|--------|---------|
| 0 — Infra Senior | 1-75 | Repo OSS-ready: CI, community files, branch protection, Scalar OpenAPI |
| 1 — Dados + Fundacao | 76-175 | Lyrics + bible_verses + auth JWT + health/metadata (8 endpoints) |
| 2 — Mirror Midia | 176-275 | mirror-media.ts + ~7.6GB Hostinger + /file/* self-hosted + sync incremental |
| 3 — Paridade 64 rotas | 276-425 | /db/* + /{lang}/* (13 rotas) + /admin/* CRUD (40 endpoints) + /tasks/* + OpenAPI |
| 4 — Plus SDA + CCB | 426-500 | import-sda-hymnal.ts (695 hinos) + audio SDA + endpoints + separacao CCB + Release v1.0.0 |

Documento de tracking: `/home/ubuntu/piano-api/PLAN.md` (atualizado a cada fase).

### FASE 0 — Status (08/08/2026)

| Item | Status |
|------|--------|
| CI workflow (lint + typecheck + test + coverage + docker build) em staging + main | FEITO |
| PR template + CODEOWNERS | FEITO |
| CONTRIBUTING.md | FEITO |
| FUNDING.yml | FEITO |
| LICENSE MIT | FEITO |
| CODE_OF_CONDUCT.md | FEITO |
| SECURITY.md | FEITO |
| README.md (badges, stack, quick start) | FEITO |
| Scalar OpenAPI UI em `/doc` (purple, modern) | FEITO |
| gh repo: description + 13 topics + branch protection (main + staging) | FEITO (08/08) |
| Branch `staging` criada no remoto | FEITO (08/08) |
| Default branch = main | FEITO (08/08) |
| Commit + push de tudo (15 arquivos) | FEITO (08/08) |

### Branch Protection — CONFIGURADA (08/08/2026)

Configurada via REST API (`PUT /repos/.../branches/{branch}/protection`). Requer token com scope `admin:org` (ou `repo` se for admin do repo).

**main:**
- required_status_checks: Lint & Format, Type Check, Tests + Coverage, Docker Build (strict: branch deve estar atualizada)
- required_pull_request_reviews: 1 approval minimo, require_code_owner_reviews: true
- enforce_admins: true (nem admin bypassa)
- required_linear_history: true (sem merge commits soltos)
- allow_force_pushes: false, allow_deletions: false

**staging:**
- Identico ao main, menos `enforce_admins: false` (admin pode override pra hotfix rapido)

### Convencao de Branching da Org (verificado 08/08/2026)

Verificado nos 4 repos da org `Piano-Louvor-JA`:
- `web` → staging + main
- `site` → staging + main
- `app` → develop + main (excecao)
- `api` → staging + main (nosso)

Padrao majoritario: **staging** (2/3 repos). Workflow: `feature/xxx → PR → staging → PR → main`.

## Workflow de Contribuicao: staging → main (atualizado 08/08/2026)

O usuario quer PRs indo para `staging` e depois `staging` → `main`. Padrao identico ao `Piano-Louvor-JA/web`.

**Status (verificado 08/08/2026):** TUDO FEITO.
- CI (.github/workflows/ci.yml): jobs (Lint, Typecheck, Test+Coverage, Docker Build) — com `staging` nos triggers. FEITO.
- Branch `staging`: criada e pushed no remoto. FEITO.
- Branch protection: configurada para `main` e `staging` via REST API. FEITO.
- Default branch: `main`. FEITO.

**CI atual (ci.yml):** 4 jobs paralelos (Lint & Format, Type Check, Tests + Coverage, Docker Build). Dispara em push/PR para `main` e `staging`. Cada job roda `npm ci` + seu step. Upload de artifact de coverage.

**Pendencia identificada (08/08):** O CI atual e FLAT (4 jobs paralelos sem gates). Melhoria proposta: refatorar para pipeline em camadas (lint → quality → build) com cache npm compartilhado e coverage gate. Isso evita rodar Docker build se lint falhou, e da feedback mais rapido. Ainda nao implementado.

### Community Health Files — FEITO (08/08/2026)

Todos os arquivos de repositorio senior criados e pushed para o GitHub:
- CONTRIBUTING.md, LICENSE (MIT), CODE_OF_CONDUCT.md, SECURITY.md, README.md
- .github/FUNDING.yml, .github/CODEOWNERS (@Piano-Louvor-JA org), .github/PULL_REQUEST_TEMPLATE.md
- .github/ISSUE_TEMPLATE/bug_report.md, .github/ISSUE_TEMPLATE/feature_request.md
- .github/workflows/ci.yml (com staging + main nos triggers)
- PLAN.md (tracking das 5 fases)

**Commit inicial pushed (08/08):** `722c659 chore: project setup` — 15 arquivos, 685 insertions. Pre-commit (biome) e pre-push (typecheck + 21 testes) passaram.

## Husky: CONFIGURADO E VERIFICADO (07/08/2026)

Confirmado funcional — "0 codigos cagados" garantido por 2 hooks:
- `.husky/pre-commit` → `npx lint-staged` (Biome check --write nos arquivos alterados, <3s)
- `.husky/pre-push` → `npx tsc + npx vitest run` (typecheck + testes completos)
- `package.json` tem `"prepare": "husky"` (instala hooks no npm install)
- lint-staged: `*.{ts,json}` → `biome check --write`

## Estado Atual (08/08/2026 — Sessão 4)

- Hono + better-sqlite3 + Zod instalado e funcionando
- 14 migrations SQL (001-011 originais + 012 colunas faltantes + 013 lyrics sem AUTOINCREMENT + 014 bible columns)
- app.ts separado de index.ts (testável vs server entry)
- Rotas compat /json_db/* IMPLEMENTADAS com paridade 9/9 (curl diff verificado)
- V1 /v1/musics, /v1/albums, /v1/categories com PARIDADE VERIFICADA via curl diff
- /file/{path} com redirect 302 pro upstream
- Importação upstream EXECUTADA com dados completos (paridade 100%):
  - 7 categorias (5 collection + 2 hymnal), 71 albums, 1889 musicas, 59520 estrofes
  - 4750 files com URLs reais, 3131 albums_musics com track, 66 livros biblicos
  - duration, dir, file_name, track, slug, type, order TODOS populados
  - 6.0 MB SQLite, 0 falhas, ~115s
- Lazy proxy bíblia IMPLEMENTADO (data/bible_cache/)
- Dockerfile multi-stage + docker-compose.yml agnóstico
- CI: lint + typecheck + test + Docker build
- Husky: pre-commit + pre-push
- **21 testes passando** (unit + integration + compat regression)
- 6 commits, repo GitHub ainda NÃO criado
- API rodando em localhost:3200 (porta provisoria)

### V1 /v1/* — PARIDADE VERIFICADA (08/08/2026)

Os endpoints V1 foram REESCRITOS traduzindo o PHP `DataBase::export_json()` de github.com/louvorja/api para TypeScript com JOINs reais. Comparação campo-por-campo com `curl https://api.louvorja.com.br/json_db/*` confirma paridade total nos response shapes:

- `GET /v1/musics` → 7 chaves: `id_music, name, has_instrumental_music, duration, lyric, albums_names, albums[]` (com pivot) — IDENTICO ao upstream `pt_musics`
- `GET /v1/musics/:id` → 10 chaves: `id_music, name, duration, instrumental_duration, url_image, image_position, url_music, url_instrumental_music, lyric[] (estrofes), albums[]` — IDENTICO ao upstream `music_{id}`
- `GET /v1/albums/:id` → 6 chaves: `id_album, name, color, url_image, categories[], musics[]` (com track/duration) — IDENTICO ao upstream `album_{id}`
- `GET /v1/categories` → array direto (sem wrapper de paginação) com `id_category, name, slug, order, albums[]` — IDENTICO ao upstream `pt_categories`

**curl diff verificado (08/08)**: duration agora retorna `"00:02:17"` (antes era null), categories retorna `["collection.aym"]` (antes era `[]`), lyrics com id_lyric original 1710, time 00:00:08, order 1, show_slide 1 — tudo batendo campo-por-campo com o upstream.

### Rotas compat /json_db/* — PARIDADE TOTAL VERIFICADA (08/08/2026, Sessão 4)

As rotas compat foram reescritas com um router generico `/json_db/:file` em `src/routes/compat.ts`. Verificacao curl diff lado-a-lado confirma 9/9 endpoints com paridade TOTAL:

```
/json_db/config          OK  keys identicas
/json_db/pt_categories   OK  5 = 5
/json_db/pt_musics       OK  1889 = 1889
/json_db/music_1         OK  10 keys identicas
/json_db/album_1         OK  6 keys identicas
/json_db/pt_hymnal       OK  601 = 601
/json_db/pt_hymnal_1996  OK  613 = 613
/json_db/pt_bible_book   OK  66 = 66
/json_db/pt_bible_version OK  10 = 10
```

### Pendências
- **RE-RODAR `fix-lyrics.ts`**: DB atual (07/08 verificado) tem `lyrics = 0` e `bible_verses = 0`. A importacao documentada acima (59.520 estrofes) foi em sessao anterior e o DB foi resetado ou sobreescrito desde entao. Antes de qualquer teste de paridade, garantir que lyrics estejam populadas.
- Criar repo GitHub Piano-Louvor-JA/api e pushar
- Cloudflare Tunnel pra teste externo
- Mirror de mídia para Hostinger 200GB (~7.6 GB — script `mirror-media.ts` a criar. Atualmente /file/ faz redirect 302 pro upstream)
- Middleware: cache LRU, rate limit, license
- Script importação sda-hymnal NPM
- Cron importação diária

### Prova de Fogo (piano-web dev mode) — VALIDADO (08/08/2026, Sessões 4-5)

Piano-web (PWA Vue 3) rodando em localhost:5174 com `.env` apontando para nossa API. Todos os 9 endpoints que o app Electron/PWA consome respondem corretamente:
- config, pt_categories, pt_musics, pt_hymnal (601), pt_hymnal_1996 (613), music_{id} (16 estrofes), album_{id} (6 musicas), pt_bible_book (66), pt_bible_version (10)
- /file/{path} com redirect 302 pro upstream
- Zero alterações no código do app — só troca de URL no .env

**Bug lyrics corrigido**: O `importMusicDetails()` crashou silenciosamente (parameter count mismatch no INSERT OR REPLACE), deixando 0 lyrics no banco. Script standalone `scripts/fix-lyrics.ts` reimportou as 59.520 estrofes com timing real do upstream (id_lyric, time, instrumental_time, show_slide, order, url_image). Após o fix, `music_1` passou a retornar 16 estrofes (antes retornava 0).

## Pitfalls (lições da implementação)

1. **Biome 2.5.7 mudou o schema** — `organizeImports` foi movido para `assist.actions.source.organizeImports`. Top-level `organizeImports` causa erro "unknown key".
2. **better-sqlite3 com AUTOINCREMENT** — não passar `null` nem usar `INSERT OR REPLACE` em colunas PK AUTOINCREMENT. Usar `INSERT` simples.
3. **FK constraint durante importação** — garantir que albums existem antes de inserir albums_musics. Adicionar `ensureAlbum.run()` antes do insertAlbumMusic.
4. **`albums` na resposta do upstream é array de objetos** — não números. Cada item tem `{id_album, name, order, type, pivot: {id_music, id_album, track}}`.
5. **Separar app.ts de index.ts** — app.ts exporta `createApp()`. index.ts importa e chama `serve()`. Vitest importa app.ts (testável), index.ts nunca é importado em testes (evita EADDRINUSE).
6. **Husky precisa de git init primeiro** — `npx husky init` falha com ".git can't be found".
7. **bible_books usa `abbreviation` não `abbrev`** — migration 009 original tinha `abbrev`, causou incompatibilidade. Corrigido para `abbreviation` + `book_number`.
8. **`/json_db/{filename}` vs `/db/{table}`** — o upstream serve formatos diferentes em cada path. `/json_db/` retorna JSON cru, `/db/` retorna com wrapper `{data, meta}`. Ambos precisam ser implementados para compatibilidade total.
9. **tsconfig `verbatimModuleSyntax: true`** — importa `package.json` com `with { type: 'json' }` mas quebra em alguns ambientes. Usar constante hardcoded quando possível.
10. **OpenAPIHono montagem de Sub-apps**: Quando mapear rotas OpenAPI via sub-routers (`app.route("/v1/musics", musicsRoutes)`), as rotas criadas com `createRoute()` **devem** ter o tipo `params: z.object({...})` (e **não** `param: z.object({...})`) na sua definição de request. Porém, ao capturar durante a execução, é preciso usar `c.req.valid('param')` (singular). Além disso, não é necessário declarar caminhos absolutos no `createRoute` se o path de montagem for utilizado corretamente.
11. **Vitest com Typescript + workspace string literal**: Vitest >= 1.0.0 necessita usar `defineWorkspace()` no arquivo `vitest.workspace.ts` no lugar de `projects` configurados inline no `vitest.config.ts`.
12. **TypeScript em Booleans SQLite (1 ou 0)**: Valores tinyint usados como booleanos que devem alimentar esquemas Zod exigem coerção no typesystem via `as 0 | 1` ou Zod `.refine()` para que não fiquem tipados só como `number`.
13. **Zod OpenAPI Tipagem**: O método de validação nos controllers de Hono precisa estar alinhado à documentação. Zod OpenAPI documenta como `params` e extrai como `.param()`.
14. **SQL no Kysely/better-sqlite3**: Evitar vazamento de IDs (como `id_language`) entre tabelas de associação puro ID, conferir explicitamente as colunas ao fazer selects restritivos.
15. **Hono Sub-apps legados no OpenAPIHono**: Ao importar um app Hono genérico para usar num app principal tipado (`OpenAPIHono`), o método correto é inicializar o roteador legado via `new Hono()` (sem tipagem strict de openAPI), definir todas as rotas dele e então importá-lo exportando a instância dele, acoplando através de `app.route("/", compatRoutes)`. Evitar funções construtoras (`createCompatRoutes(app)`) pra não haver mismatchs de tipos e crashes.
16. **TDD em refatoração de rotas legadas (Project Excellence)**: **Jamais** alterar contratos existentes em refatoração sem que antes os Testes de Integração por "Snapshot"/Contrato Original (Golden Master) estejam implementados e rodando. Os testes das rotas legadas devem cobrir tanto endpoints com `JSON` aninhado quanto cru, refletindo a API de produção. Coverage abaixo de 70% em rotas críticas em migração barra o commit.
17. **Cuidado com replaces cegos (`sed` e Regex)**: Em refatorações extensas na montagem do app Hono, validar o arquivo completo antes de aplicar remoções por `sed` (como quando o import com `createCompatRoutes` foi sobrescrito de maneira falha na linha exata por ter casting em Typescript `app as any`).
18. **Campos de imagem (URL vs ID do arquivo)**: O banco SQLite do LouvorJA é estritamente relacional. A tabela `musics`, `albums`, e `categories` NÃO possui a coluna `url_image`, apenas a foreign key `id_file_image`. Para montar a URL final no JSON (que a API oficial fornece e o Zod Schema exige), **NUNCA** faça concatenação cega via JavaScript (`map(row => ({url_image: "url/" + row.id_file_image + ".jpg"}))`) — isso gera URLs falsas/quebradas (resultando em "Arquivo não encontrado!"), pois nem todo arquivo é um .jpg com o nome igual ao ID.
    *   **A Abordagem Correta**: Use queries `LEFT JOIN` reais com a tabela `files` (`LEFT JOIN files f_image ON m.id_file_image = f_image.id_file`). A tabela `files` contém as URLs definitivas, prontas e perfeitas na coluna `f_image.url`. Exporte essa coluna como `url_image` no Select (`f_image.url as url_image`).
19. **PARIDADE ANTES DE CODIFICAR (Lição crítica)**: **JAMAIS** implemente endpoints da nossa API sem antes estudar o response shape exato do upstream. O usuário não quer "parecido" — quer **paridade idêntica, zero atrito**. Na sessão 07/08/2026, a V1 inteira foi construída com `SELECT * FROM musics` (retornando colunas cruas como `id_file_image`) sem consultar como a API oficial responde. O resultado foi que nossos `/v1/musics` retornava um shape completamente diferente do `/json_db/pt_musics` oficial: sem `lyric` embedded, sem `albums[]` aninhados, sem `duration`, sem `albums_names`. O usuário classificou como "serviço porco" e "feito nas coxas" — com razão.
    *   **Fluxo OBRIGATÓRIO antes de escrever qualquer rota nova**: (1) `curl -s https://api.louvorja.com.br/json_db/{endpoint}` para capturar o JSON real; (2) Documentar o shape exato; (3) Construir a query SQL com JOINs para reproduzir o shape; (4) Validar com Zod schema que bate campo-por-campo com o upstream; (5) Teste de integração que compara nossa resposta com a oficial.
    *   **Referência completa dos response shapes**: ver `references/api-upstream-endpoint-mapping.md` neste skill.
    *   **O upstream é mais rico que o SQLite cru**: `/json_db/pt_musics` embute `lyric` (texto), `albums[]` (array de objetos com pivot), `albums_names`. `/json_db/music_{id}` embute `lyric[]` (array de estrofes com timing). `/json_db/album_{id}` embute `musics[]` e `categories[]`. `/json_db/pt_categories` embute `albums[]`. Isso requer JOINs multiplos e agregação no SQL ou pós-processamento TypeScript — nunca `SELECT *` puro.
19. **Teste com Bancos Incompletos / Falsos Positivos**: Não force injeção de tabelas que não existem no banco de dados mock para satisfazer o TDD (como injetar `bible_chapters` se ela nem foi criada no seu `.db`). Isso vai quebrar o teste e causar "SqliteError: no such table" mascarando o resultado dos outros testes que operam tabelas reais.
20. **SQLite não suporta GROUP_CONCAT(DISTINCT col, separator)**: O MySQL do upstream usa `GROUP_CONCAT(DISTINCT col SEPARATOR '|')` mas SQLite rejeita `DISTINCT aggregates must have exactly one argument`. Solução: usar `GROUP_CONCAT(col, '|')` simples (sem DISTINCT) envolvendo a subquery com `GROUP BY` para eliminar duplicatas antes da concatenação.
21. **SQLite ALTER TABLE ADD COLUMN é idempotente só com try/catch**: SQLite não tem `ADD COLUMN IF NOT EXISTS`. Se a migration roda múltiplas vezes (ex: test DB reusado), `ALTER TABLE` crasha com `duplicate column name`. Solução: no `initDb()`, envolver cada `db.exec(sql)` em try/catch que ignora `duplicate column name` silenciosamente. Ver `src/db/connection.ts`.
22. **As migrations originais (001-011) estavam SIMPLIFICADAS demais vs MySQL upstream**: Faltavam colunas críticas: `files` não tinha `duration`, `dir`, `file_name`, `version`, `image_position`; `categories` não tinha `slug`, `order`, `type`; `categories_albums` não tinha `name`, `order`, `id_language`; `albums_musics` não tinha `track`, `id_language`. Causa raiz das paridades quebradas. Corrigido com migration 012 (`ALTER TABLE ADD COLUMN` para todas). Sempre comparar o schema SQLite com o MySQL do `louvorja/api` antes de implementar endpoints.
23. **O código-fonte PHP do upstream É a fonte da verdade para queries**: O arquivo `app/Helpers/DataBase.php` no repo `github.com/louvorja/api` contém a função `export_json()` que gera todos os JSONs estáticos servidos em `/json_db/`. Cada query Eloquent/SQL ali dentro é exatamente o que precisa ser traduzido para TypeScript. NÃO inventar queries — traduzir do PHP. O arquivo `GenerateStaticJsons.php` gera um segundo conjunto de JSONs (formato ligeiramente diferente, com `_meta` envelope). Os apps consomem os JSONs do `DataBase.php` (sem envelope).
24. **Paridade se VERIFICA com curl lado-a-lado, não com testes unitários**: Após reescrever uma rota V1, o teste real de paridade é: `curl localhost:PORTA/v1/endpoint | jq 'keys'` comparado com `curl https://api.louvorja.com.br/json_db/endpoint | jq 'keys'`. Se as chaves batem campo-por-campo, paridade alcançada. Testes unitários só verificam shape genérico (tem `id_music`?), não paridade real.
25. **O script de importação PRECISA popular todas as colunas novas da migration 012**: A primeira versão do `import-upstream.ts` só populava colunas básicas (id, name, id_language) e ignorava duration, slug, type, order, track, dir, file_name. Isso causou paridade aparente nas chaves do JSON mas valores `null` nos campos críticos. O script reescrito (08/08/2026) baixa de `/json_db/{endpoint}` (formato cru sem wrapper) e popula TODAS as colunas: `duration` de `files.duration`, `slug`/`type`/`order` de `categories`, `track` do `pivot.track` do upstream, `dir`/`file_name` via parse do path, `id_lyric` original do upstream.
26. **O app Electron consome via `/json_db/{filename}` (formato cru), NÃO via `/db/{table}` (com wrapper)**: Mapeado do código-fonte do app em `src/shared/services/remote-catalog.ts` e `workspace-api.ts`. O app chama `resolveDatabaseUrl(filename)` que monta `${VITE_URL_DATABASE}/${filename}` onde `VITE_URL_DATABASE=https://api.louvorja.com.br/json_db`. Os filenames que o app busca são: `config`, `pt_categories`, `pt_hymnal`, `pt_hymnal_1996`, `album_{id}`, `music_{id}`. Para midia (imagens/MP3), o app usa `resolveMediaUrl(path)` que monta `${VITE_URL_FILES}/${path}` onde `VITE_URL_FILES=https://api.louvorja.com.br/file`.
28. **Hono não suporta rotas com prefixo dinâmico (`/json_db/music_:id`)**: O Hono faz pattern matching de rotas e não consegue interpretar `music_:id` como path. Solução: usar um router genérico `/json_db/:file` e fazer regex matching dentro do handler (`file.match(/^music_(\d+)$/)`). Esse pattern acomoda `config`, `pt_musics`, `pt_categories`, `pt_hymnal`, `pt_hymnal_1996`, `music_{id}`, `album_{id}`, `pt_bible_book`, `pt_bible_version`, `bible_{v}_{b}_{c}` numa única rota.
29. **O upstream tem DOIS helpers PHP que geram JSONs**: `app/Helpers/DataBase.php` tem `export_json()` que gera os JSONs SEM envelope (`pt_musics.json`, `music_1.json`, etc). `app/Helpers/GenerateStaticJsons.php` tem `generate()` que gera JSONs COM envelope `_meta` + `data`. Os apps (Electron, Web) consomem os do `DataBase.php` (sem envelope). O `DatabaseJsonController.php` serve ambos dependendo da rota: `/json_db/{file}` serve sem envelope, `/db/{table}` serve com wrapper `{data, meta}` de paginação Lumen.
30. **Hinários (hymnal/hymnal_1996) não vêm de /json_db/pt_categories**: O upstream serve `pt_categories` que só lista categorias `type='collection'`. Os hinários são categorias `type='hymnal'` que só existem no MySQL. O script `import-upstream.ts` precisa CRIAR essas categorias manualmente (INSERT OR IGNORE com IDs virtuais 100 e 101) e linkar os albums virtuais (IDs 1000 e 1001) com os tracks do `/json_db/pt_hymnal` (601 hinos) e `/json_db/pt_hymnal_1996` (613 hinos). Sem isso, `/json_db/pt_hymnal` retorna array vazio na nossa API.
31. **Migration com DROP TABLE + RENAME precisa de DROP IF EXISTS do estado intermediário**: A migration 013 faz `CREATE lyrics_new → INSERT FROM lyrics → DROP lyrics → RENAME lyrics_new TO lyrics`. Em DBs de teste que rodam múltiplas vezes, `lyrics_new` pode já existir de uma execução anterior. Adicionar `DROP TABLE IF EXISTS lyrics_new` antes do CREATE para evitar "table already exists".
32. **O script de importação pode falhar SILENTIOSAMENTE em lyrics**: O `importMusicDetails()` tem um loop que busca `music_{id}` do upstream, deleta lyrics antigas, e insere as detalhadas. Se houver um erro de parameter count mismatch no `INSERT OR REPLACE` (ex: 3 params na SQL mas 2 passados via `.run()`), o better-sqlite3 lança `RangeError: Too many parameter values` que CRASHA o processo inteiro, matando a importação de lyrics para TODAS as musicas restantes. O resultado: 0 lyrics no banco apos importação, sem erro visível no output final (o processo termina com exit 1 mas o `main()` ja tinha printado "IMPORTACAO CONCLUIDA"). **Solução**: (a) Sempre verificar `SELECT count(*) FROM lyrics` apos importar; (b) Rodar `scripts/fix-lyrics.ts` standalone se lyrics estiverem zeradas; (c) Validar parameter count de cada `.prepare()` antes de loopar 1889 musicas.
33. **Prova de fogo: piano-web dev mode apontando para nossa API**: Para validar zero-atrito na pratica, trocar o `.env` do piano-web de `VITE_URL_DATABASE=https://api.louvorja.com.br/json_db` para `http://localhost:3200/json_db` e `VITE_URL_FILES` para `http://localhost:3200/file`. Subir piano-api (`PORT=3200 npx tsx src/index.ts`) e piano-web (`npx vite --port 5174 --host`). Validar com curl cada endpoint que o app chama: config, pt_categories, pt_musics, pt_hymnal, music_{id}, album_{id}, pt_bible_book, pt_bible_version. Se todos responderem 200 com os dados certos, a troca de URL base funciona sem alterar codigo do app.
34. **Endpoint coverage: o Electron NAO consome a API REST completa do upstream**: O upstream tem ~50 endpoints (CRUD de musics, albums, categories, lyrics, files, users, auth, admin tasks, etc). O app Electron so consome 2 paths: `/json_db/{filename}` (JSONs estaticos) e `/file/{path}` (midia). Os endpoints `/player/*`, `/admin/*`, `/auth/*` sao do painel web/admin do louvorja, nao do app desktop. Para "zero atrito" no Electron/PWA, so precisamos dos 10 filenames que o app busca + redirect de /file/. Nao e necessario reimplementar a API REST inteira do upstream.
36. **Mixed Content: HTTPS -> HTTP bloqueia fetch no browser (CORS não é o culpada)**: Quando o piano-web roda atrás de um Cloudflare Tunnel (HTTPS) e o `.env` aponta `VITE_URL_DATABASE` para `http://localhost:3200` (HTTP), o browser bloqueia TODOS os fetch com "TypeError: Failed to fetch". O CORS da API (`Access-Control-Allow-Origin: *`) não resolve — o problema é mixed content (página HTTPS não pode buscar recurso HTTP). **Solução**: Expor a API também via Cloudflare Tunnel (`cloudflared tunnel --url http://localhost:3200`) e apontar o `.env` para a URL HTTPS do tunnel (`VITE_URL_DATABASE=https://xxx.trycloudflare.com/json_db`). Sempre que testar piano-web via tunnel, a API também precisa estar em HTTPS.
37. **Workbox PWA cachea URLs cross-origin por path, não por origem**: Os warnings "Precaching did not find a match for http://localhost:3200/json_db/pt_hymnal" no console do piano-web são do Workbox (service worker) tentando cachear requisições para a API. Isso é COSMÉTICO — o app funciona normalmente, o fetch vai direto pra rede. Mas se quiser suprimir, configurar `runtimeCaching` no vite-plugin-pwa para ignorar URLs cross-origin ou excluir o domínio da API do escopo do service worker.
38. **ALIAS DE COLUNAS: SQLite column name ≠ upstream JSON field name (classe recorrente)**: Esse bug apareceu em pt_musics (id_file_image → url_image via JOIN), em albums (url_image), e AGORA em pt_bible_book/pt_bible_version. O SQLite usa `id_book` mas o upstream/app espera `id_bible_book`. O SQLite usa `id_version` mas o upstream espera `id_bible_version`. O app faz `:key="book.id_bible_book"` no Vue — se a API retorna `id_book`, o key vira `NaN` e quebra o render. **Regra**: SEMPRE comparar `curl localhost:PORTA/json_db/{endpoint} | jq 'keys'` com `curl https://api.louvorja.com.br/json_db/{endpoint} | jq 'keys'`. Se uma chave do upstream não existe no seu SELECT, usar `AS` alias: `SELECT id_book AS id_bible_book, ...`. Verificar tambem campos extras que o upstream retorna mas voce nao selecionou (testament, keywords, color em bible_books; abbreviation em bible_versions).
39. **Console errors do piano-web: triagem rápida**: Quando o usuario colar logs de console do navegador, classificar em 3 categorias antes de agir: (a) **Extensao do browser** — `ObjectMultiplex orphaned data`, `contentScript.js`, `installHook.js` — sao de MetaMask/wallet/Vue Devtools, NAO sao do app. Ignorar. (b) **Dev-mode noise** — `[vite] failed to connect to websocket` (HMR via tunnel Cloudflare nao suporta WS), `workbox Precaching did not find a match` (SW tentando cachear cross-origin). Cosmetico, nao quebra nada. (c) **BUGS REAIS** — `[Vue warn]: VNode created with invalid key (NaN)` indica que o JSON da API nao tem o campo esperado pelo template. Investigar qual campo falta comparando keys do response com o que o componente usa no `:key=` ou `v-for`.
40. **Processo Node nao morre com kill simples em background shell**: Ao reiniciar a API apos um patch, `kill <PID>` pode nao matar todos os filhos (npx → npm → node → tsx). Usar `pkill -f "tsx src/index"` para matar a arvore inteira. Confirmar com `pgrep -f "tsx src/index"` antes de subir de novo, senao o processo antigo continua servindo codigo velho e o patch parece nao ter efeito.
41. **Service Worker (Workbox) cachea respostas da API e serve dados antigos apos fix**: Quando voce corrige um field name na API (ex: `id_book` → `id_bible_book`), o browser continua recebendo a resposta ANTIGA do cache do Service Worker. O `?20260807` querystring de cache-busting nao ajuda se o SW interceptou e cacheou aquela URL completa. **Sintoma**: o fix funciona numa aba anonima mas nao na aba normal. **Solucao**: orientar o usuario a (a) Abrir DevTools → Application → Service Workers → Unregister, (b) Application → Cache Storage → deletar caches `piano-*` e `workbox-*`, (c) reabrir a aba em nova aba. Aba anonima sempre funciona para teste porque o SW nao esta registrado la.
42. **Bible chapter proxy DEVE ser transparente, nunca retornar erro de "nao cacheado"**: O modulo de biblia do piano-web chama `/json_db/bible_{version}_{book}_{chapter}` para cada capitulo selecionado. Se a API retorna `{error: "Versiculo nao cacheado"}`, o usuario ve a tela de versiculos vazia. O handler deve SEMPRE fazer `fetch(${UPSTREAM}/json_db/${cacheKey})` quando o capitulo nao estiver em cache local, salvar em `data/bible_cache/`, e retornar o JSON. A rota `/json_db/:file` precisa ser `async` para suportar isso.
43. **Docker build: `npm ci --omit=dev` executa o script `prepare: husky` que falha com exit 127 (husky not found)**: O `package.json` tem `"prepare": "husky"` que roda automaticamente em qualquer `npm install`/`npm ci`. No runtime stage do Docker (`npm ci --omit=dev`), o husky nao e instalado (e devDep), mas o hook `prepare` dispara `husky` → `sh: 1: husky: not found` → exit 127. **Solucao**: Em vez de `npm ci --omit=dev` no runtime stage, fazer `npm prune --omit=dev` no BUILDER stage (onde devDeps ja estao instaladas e o prepare hook ja rodou) e copiar `node_modules` podado pro runtime stage. Isso preserva modulos nativos compilados (better-sqlite3) sem disparar hooks de dev. Ver Dockerfile atual.
44. **Trailing comma em package.json quebra `npm ci` no CI**: O biome ou edicoes manuais podem deixar uma virgula apos o ultimo item de um bloco (`"prepare": "husky",\n  },`). JSON valido em JS/TS5 mas INVALIDO para `JSON.parse` do npm. O CI falha com `EJSONPARSE: Expected double-quoted property name in JSON at position NNN`. **Solucao**: Sempre validar com `node -e "JSON.parse(require('fs').readFileSync('package.json','utf8'))"` apos editar package.json. O patch tool (skill_manage/patch) nao valida JSON estrito.
45. **Husky pre-commit com lint-staged pode falhar apos `npm prune --omit=dev`**: Se voce roda `npm prune --omit=dev` localmente (para testar o Docker build), o lint-staged e husky sao removidos. O proximo `git commit` falha com `lint-staged could not find any valid configuration`. Workaround: `npm ci` para reinstalar, ou `git commit --no-verify` para bypass temporario.
46. **Vitest com better-sqlite3 singleton: `fileParallelism: false` sozinho e INSUFICIENTE**: O `fileParallelism: false` faz testes rodarem sequencialmente, mas ainda no MESMO processo Node. Como `connection.ts` tem `let db: Database | null = null` (singleton modulo-level), o segundo test file que chama `initDb()` sobrescreve o singleton do primeiro. **Solucao comprovada**: `:memory:` + `pool: 'forks'` em `vitest.workspace.ts`. Cada test file roda em processo filho separado com seu proprio singleton e seu proprio DB em memoria. Ver skill `vitest-unit-config`, arquivo `references/sqlite-memory-test-isolation.md`.
47. **WebSocket com @hono/node-ws: upgradeWebSocket DEVE estar registrado no MESMO app raiz que roteia** (WT-5a, 01/09/2026): Se registrar a rota WS num sub-app (`app.route("/v1/palco", palcoRoutes)`) e o `createNodeWebSocket({ app: palcoRoutes })` apontar pro sub-app, o handshake retorna 404 ("Unexpected server response: 404" no client). Validado com spike: o correto é `const palcoWs = createNodeWebSocket({ app })` no app raiz + `app.get("/v1/palco/relay/:code", palcoWs.upgradeWebSocket(...))` com path COMPLETO. `baseUrl` do createNodeWebSocket é a base p/ resolver `request.url` relativo, NÃO um strip de prefixo. Bootstrap: `getPalcoWs().injectWebSocket(server)` no index.ts (server mock em testes precisa ter `.on()`). Ver `references/palco-relay-wt5a.md`.
48. **createApp() deve manter retorno compatível**: ao adicionar WS/bootstrap ao app, NÃO mudar o retorno de `createApp()` de `app` para `{ app, ws }` — 20+ testes usam `createApp().request(...)` direto e quebram em massa (69 falhas numa tacada). Padrão: manter `return app` e expor o helper via getter singleton (`setPalcoWs()` chamado dentro de createApp, `getPalcoWs()` consumido pelo index.ts/testes).
49. **Relay WS fire-and-forget: room nunca deve sumir por "vazia + nova criação"**: sweep por TTL apenas. Room vazia com idade < TTL é legítima (intervalo entre createRoom e primeiro client conectar). Se o sweep deletar rooms vazias, criar room B mata a room A recém-criada e o teste "2 rooms coexistem" falha com `getRoom` retornando null.
50. **npm peer-deps conflitantes: `@hono/node-ws` exige `@hono/node-server@^1.x` mas o repo usa 2.x**: `npm install` falha com ERESOLVE. Instalar com `npm install @hono/node-ws --legacy-peer-deps` (funciona na prática, npm ls mostra `invalid` mas o par de versões opera corretamente — validado em testes E2E com WS real).
51. **Upstream saturado: Workers.dev como fallback + apps com base URL hardcoded**: A API oficial (`api.Piano-Louvor-JA.com.br`) tem histórico de saturação — medido 04/09/2026: `/json_db` (2,2MB) respondendo em **14s** na oficial vs **0,12s** no fallback `https://api.louvorja.workers.dev/` (~116x). Sintoma nos apps: "não toca / não carrega mas não dá erro" — timeout longo parece falta de resposta. O APK Flutter tem a URL oficial HARDCODED em ~20 pontos (`DownloadUrlBuilder._filesBase`, `album_detail_page.dart`, `hymns_page.dart`, `router.dart`, `bible_page.dart`, `liturgy_*` etc). Plano acordado: (1) espelhar catálogo completo (18.060 JSONs: 15.457 bible + 2.509 music + 82 album + índices) + mídia (~7,6GB) da oficial; (2) centralizar base URLs num único `ApiEndpoints`; (3) failover oficial → workers.dev → própria API. Espelho local em `/media/contribuidor/NovoVolume/louvorja-mirror/` (`db/index.json` = índice com hash de cada arquivo; `xargs -P 12` dá ~7 arquivos/s sem derrubar o upstream).
52. **Offline-first do APK tem furo: `_openNowPlaying` busca API mesmo com MP3 local**: O caminho `_playTrack` da lista respeita offline-first (`PlaybackResolver.localFor` → toca local sem API), mas `_openNowPlaying` (modo vídeo/slides) SEMPRE chama `_repository().getHymnDetails()` antes de resolver a fonte — com upstream saturado, parece "não toca". Arquivos offline vivem em `getApplicationDocumentsDirectory()/music-offline/` (`{musicId}_vocal.mp3` / `{musicId}_instrumental.mp3` + `music_offline_index.json`) — sandbox privado, invisível em file manager; release build não é debuggable então `run-as` não funciona pra inspecionar.
53. **PALCO_RELAY_KEY: sessão criada mas WS recusado com 4404 = secret ausente no processo**: O relay exige `secretKey()` (`PALCO_RELAY_KEY ?? REMOTE_SESSION_KEY`) no `getRoom()`, mas `createRoom()` NÃO checa. Resultado bizarro: `POST /sessions` cria sessão normal, e TODO WebSocket fecha `4404 sessao_invalida` — parece bug de roteamento mas é env. Fix definitivo (commits `866c4c7` + `dd19515`, 05/09/2026): (a) `package.json` — `start`/`dev` usam `--env-file-if-exists=.env` (Node 24 nativo); (b) `src/index.ts` — `try { loadEnvFile(".env") } catch {}` antes de `validateEnv`, cobrindo `node dist/index.js` direto (qualquer launcher). `.env` local não versionado; `.env.example` documenta a variável.
54. **Debug de WS do Palco: 3 camadas, testar na ordem**: (1) processo de dev externo pode servir `dist/` ANTIGO após rebuild — sempre confirmar PID + start time do processo na porta (`ss -tlnp | grep 3100` + `ps -o lstart`) vs horário do último build; (2) env sem chave → ver pitfall 53; (3) sessões são IN-MEMORY: qualquer restart invalida TODOS os códigos, e receivers/PWAs reconectam automaticamente com o código salvo no localStorage tomam 404 silencioso (tela preta). O receiver agora trata 404 do token com "Sessão expirada — informe o código novo" (limpa localStorage, volta pro setup). Ao reiniciar a API, SEMPRE avisar o operador pra criar sessão nova.
55. **Service Worker do receiver: bump de CACHE a cada mudança no static/palco**: `static/palco/sw.js` usa const `CACHE = 'palco-receiver-vN'`. Mudança no `index.html` sem bump = receivers já instalados continuam no shell antigo pra sempre (parece que o fix não teve efeito). O HTML é network-first pra `navigate`, mas o SW só atualiza se o nome do cache mudar. Histórico: v5 → v6 (log debug do botão nova tela). Validar sintaxe inline com: extrair `<script>` e `node --check`.
56. **E2E do relay por WebSocket fake**: Para validar roteamento sem navegador, usar `ws` direto: criar sessão via `curl -X POST /v1/palco/sessions`, conectar 2+ receivers com `role=receiver&cid=X&slot=N`, operator envia `{v:2, to:'slot-2', ...}` e verificar quem recebeu. Scripts locais `wt5-*.mjs`/`wt6a-*.mjs` na raiz do repo (gitignored, não são código — decisão do o PO: utilitários não commitam). Unit tests com app em memória NÃO pegam problema de build/env — E2E contra o server real pega (foi assim que achou o dist antigo e o env faltando).
57. **Console errors de receiver PWA: triagem antes de agir**: `contentScript.js`, `ObjectMultiplex`, `ChromeTransport inpage.js` = extensão do navegador (MetaMask etc), SEMPRE irrelevante. `sw.js Failed to fetch` em navigate = API caída no load OU shell cacheado antigo (bump do CACHE). `beforeinstallprompt.preventDefault()` é esperado — o PWA usa botão próprio de instalação. Diagnóstico de "botão não faz nada" no receiver: instrumentar o handler com `console.log` + fallback visível no próprio botão (ex: texto vira "✕ Pop-up bloqueado" quando `window.open` retorna null) — usuários leigos não abrem DevTools.
58. **URLs de mídia vêm com barra inicial e espaços/acentos — SEMPRE normalizar antes de montar `/file/*`**: O upstream retorna `url_image: "/covers/1992.bmp"` e `url_music: "/musics/pt/1992 - Brilha Jesus/Nosso Sol É Jesus.mp3"`. Concatenação cega `filesBase + path` produz `/file//covers/...` → **400** (reproduzido 06/09/2026 via curl: dupla barra 400, normalizada 200 image/bmp). Padrão no Flutter: `DownloadUrlBuilder.build()` (`core/services/download_url_builder.dart`) — strip `RegExp(r'^/+')`, `Uri.encodeComponent` por segmento preservando barras. Validação via curl precisa do encoding: `%20` para espaço, `%C3%89` para É. Armadilha extra: `/file/mp3/1.mp3` retorna 302→upstream→404 — o caminho REAL de áudio é o `url_music` do JSON (`/file/musics/pt/...`); validar SEMPRE o path exato que o app monta, não paths "plausíveis". **Fix commitado no Flutter** (`94019eb`, PR #51 Piano-Louvor-JA/apk → staging): `DownloadUrlBuilder.build()` + `debugPrint` de stack real em falha de play (o catch genérico "Sem conexão" escondia a causa). Validação E2E no device (06/09): covers 200, MP3 remoto 200 audio/mpeg, offline OK, logcat limpo.
59. **Túnel trycloudflare é EFÊMERO — validar antes de culpar o app (06/09/2026)**: Build de teste com `--dart-define=LOUVORJA_URL_DATABASE=...trycloudflare.com/json_db` morre quando o PC que criou o túnel desliga. Sintoma no device idêntico a bug de app ("não carrega cover / não toca, sem erro claro"). Ordem de diagnóstico comprovada: (1) `curl -s -o /dev/null -w "%{http_code}" "$TUNNEL/json_db/album_1?typ=db"` → 200 ou túnel morto; (2) comparar `lastUpdateTime` do APK no device (`adb shell dumpsys package <pkg> | grep lastUpdateTime`) vs horário do commit do fix vs `stat` do APK local — APK buildado ANTES do commit não contém o fix; (3) rebuild com dart-define do túnel ATUAL + reinstall. Nota: os ~20 hardcodes do pitfall 51 foram resolvidos pelo `ApiConfig` centralizado (commit `d1122df`) — URLs sobrescrevíveis via `LOUVORJA_URL_DATABASE`/`LOUVORJA_URL_FILES`, defaults = API oficial.
61. **Categorias/feature novos podem existir SÓ no espelho — oficial pode estar atrasada (06/09/2026)**: categorias Infantis (98) e Doxologia (99), albums 9000-9014 e músicas ≥90100 existiam APENAS no túnel espelho (`trusted-catalogue...trycloudflare`); a oficial `api.Piano-Louvor-JA.com.br` não tinha (`album_9000` → "Arquivo não encontrado", `pt_musics` 1889 sem nenhum ≥90100), e o piano-api local :3100 também servia os dados do upstream. Apps (APK Flutter e piano-app) renderizam `{lang}_categories` DINAMICAMENTE — se a categoria nova não aparece, a causa é a FONTE (deploy pendente dos JSONs no servidor oficial), não código de app. Diagnóstico antes de propor solução: comparar `curl {oficial}/json_db/pt_categories` vs `{espelho}/json_db/pt_categories`. Para teste local imediato: APK com `--dart-define` do túnel (pitfall 59) ou piano-app com `.env.local` (pitfall 60); para produção, popular/deployar no oficial. **Álbuns do espelho podem vir com `url_image: null`** (9000-9014 sem capa BMP) — o app renderiza com cor sólida de fallback, que é o comportamento correto; capa precisa de upload do BMP no espelho.

62. **ADB wireless: portas são efêmeras, mas o pareamento persiste via mDNS (06/09/2026)**: a porta de conexão do "Depuração por Wi-Fi" muda a cada ativação (não é sempre 5555 — pode ser efêmera tipo 38851) e some após tempo/reboot ("Connection refused"). Fluxo: usuário liga Depuração por Wi-Fi e passa IP:porta + código → `echo "CODIGO" | adb pair IP:PORTA_PAREAMENTO` → `adb connect IP:PORTA_CONEXAO`. Após pair OK, o device reaparece sozinho como `adb-RQ8Yxxxxx._adb-tls-connect._tcp` na lista `adb devices` — usar esse nome como `-s` (não precisa do IP:porta). `adb install -r` reinstala preservando dados; confirmar versão com `dumpsys package <pkg> | grep lastUpdateTime` (sintoma clássico de "teste não funcionou": device rodando APK antigo). adb não está no PATH: usar `export PATH=$PATH:~/Android/Sdk/platform-tools`.

60b. **Electron desktop é app desktop — NÃO testar abrindo o Vite no browser (correção do o PO, 06/09/2026)**: para testar piano-app (Electron), lançar `electron .` de verdade, não só o dev server no navegador. Receita comprovada: (1) subir Vite do piano-app em porta própria (`npx vite --host 127.0.0.1 --port 5175 --strictPort` — 5173 costuma ser piano-web, conferir `ss -tlnp | grep 517x`); (2) `env -u ELECTRON_RUN_AS_NODE VITE_DEV_SERVER_URL=http://127.0.0.1:5175 ./node_modules/.bin/electron . --class=louvorja-piano` — usar o binário local `./node_modules/.bin/electron` porque `cross-env` pode não estar no PATH do shell não-interativo (o script `electron:dev` do package.json assume porta 5173 ocupada pelo piano-web). Validar com `wmctrl -l` (janela "LouvorJA - PIANO" presente) ou `pgrep -fa electron`. **Screenshot da janela Electron via `import`/`xwd` sai PRETO** (GPU compositing) — para validar o override de API sem screenshot, buscar a URL do túnel no bundle servido: `curl http://127.0.0.1:5175/src/shared/services/workspace-api.ts | grep -oE "https://[a-z-]+\.trycloudflare\.com[^\"']*"` — se aparecer o túnel, o renderer está apontando pra ele.

60. **piano-app (Electron desktop) aceita override de API via `.env.local` — sem rebuild (06/09/2026)**: Mesmo esquema VITE_ do piano-web (pitfall 33), mas em `<clone local do app>/`: criar `.env.local` (não versionado, sobrescreve `.env`) com `VITE_URL_DATABASE`/`VITE_URL_FILES` apontando pro túnel e subir o vite. Não confundir dev servers: `ss -tlnp | grep 517x` — a 5173 costuma ser o piano-web; subir o piano-app em outra porta (`npx vite --port 5175 --strictPort`). Caveat: `electron/constants.mjs` tem `API_BASE_URL = 'https://api.Piano-Louvor-JA.com.br'` HARDCODED para o main-process — o override `.env.local` cobre só o renderer (Vite); se o módulo testado roda no main, conferir esse arquivo.

63. **Ordem de categorias na Central de Mídia: Infantis/Doxologia ficam NO COMEÇO (correção do o PO, 07/09/2026)**: A API do espelho retorna as categorias em ordem crua (Infantis 98/Doxologia 99 NO FIM do array), mas a expectativa do usuário é Hinários → CDs Oficiais/Ano → **Infantis → Doxologia** → demais (ordem que "antes tava"). O `CATEGORY_ORDER` de `library-catalog.ts` (biblioteca local) não cobre a Central — `album-catalog.ts` (`loadAlbumCategories`) precisou do MESMO sort replicado. Fix commit `76c6ed4` (Piano-Louvor-JA/app, feat/remote-palco-slots) + unit test `album-catalog-order.test.ts`. **Lição de processo**: ao introduzir categorias novas, replicar a ordenação em TODOS os catálogos que listam categorias (biblioteca local E central de mídia) — são módulos com lógica de sort separada.

64. **Espelho pode ter JSON de categoria/álbum novo SEM mídia — resultado é "listado mas não toca/sem cover" em TODO app (07/09/2026)**: O espelho do túnel tinha os JSONs de 98/99/albums 9000-9014/músicas ≥90100, mas os records vinham com `url_image: null` e `url_music: null` (comparar `music_1` antigo, que tem `/musics/pt/...mp3`), e os arquivos físicos covers/mp3 9000+ não existiam em lugar nenhum — `/file/covers/9000.bmp` → 302 → API oficial → 404 (oficial também não tem). Sintoma no app: categoria renderiza, mas sem capa e sem áudio. **Regra de diagnóstico**: antes de culpar código de app, verificar no JSON da fonte se `url_music`/`url_image` estão populados (`curl $TUNNEL/json_db/music_90122?typ=db`) e se o arquivo físico responde. Sem assets, a pendência é da equipe subir os arquivos no espelho — fluxo rascunho → PV → curadoria → PV Elias. **Atenção**: o backend do túnel pode ser um espelho DIFERENTE do piano-api local :3100 — nesta sessão o túnel retornava 7 categorias e o DB local 5, com 98/99 ausentes no SQLite local. Não assumir que túnel = :3100.

65. **CDP HTTP do Electron pode aceitar conexão e nunca responder — validar UI de outra forma (07/09/2026)**: Electron com `--remote-debugging-port=9222` logava "DevTools listening on ws://..." mas `curl /json/list`, WebSocket ao endpoint do browser e `net.connect` + HTTP todos travavam sem resposta (TCP conecta, zero bytes). Não perder a sessão nisso: a validação equivalente via **unit test do código sob teste** (ex: extrair o sort de categorias num `.test.ts` e rodar `npx vitest run <arquivo>`) cumpre o papel quando o que se valida é lógica pura. Para inspecionar DOM/estado do renderer, tentar `--remote-allow-origins=*` (citado entre aspas no shell, senão o zsh expande o `*` e o Electron nem sobe: "no matches found").

66. **Popular categorias/coletâneas novas na API: músicas 90xxx são COMPILAÇÕES do acervo — linkar, não subir mídia nova (07/09/2026)**: As 70 faixas dos álbuns Infantis (9000) e Doxologia (9010-9014) são 100% compilações de músicas JÁ existentes no acervo (match por nome em `pt_musics` deu 70/70, ex: 90141 "Santo Lugar" = id 67). O cadastro do espelho criou os ids 90xxx SEM linkar arquivos (`url_music: null`, `url_image: null`) — por isso "listado mas não toca". **Receita de populate (testada, ~5min)**: (1) `cp data/catalog.db data/catalog.db.backup-<data>`; (2) baixar os JSONs dos álbuns novos da fonte que os tem (espelho do Ezequias) e fazer match por `name.lower().strip()` contra `SELECT m.id_music, m.name, f.url FROM musics m JOIN files f ON f.id_file=m.id_file_music` — reutilizar o `files.id_file` EXISTENTE pela `url` (0 files novos, mp3 já coberto pelo mirror on-demand do upstream → 70/70 HEAD 200); (3) INSERT em `musics` (id_music 90xxx, id_file_music=fid), `albums_musics` (track sequencial), `albums`, `categories_albums`, `categories` (98/99, type='collection'); (4) covers: gerar BMP 137x137 placeholder com PIL (cor da coletânea + iniciais, fonte DejaVuSans-Bold) em `media/covers/{id}.bmp` + INSERT em `files` (type='image') + `UPDATE albums SET id_file_image=...`. **O mirror on-demand do `/file/*` cobre os mp3 do acervo automaticamente** — path de música que existe no upstream nunca dá 404. better-sqlite3 reflete os INSERTs na hora (sem restart da API). Covers gerados são placeholder — substituir o BMP em `media/covers/` pela arte oficial quando existir (a API serve na hora, sem restart).

67. **`.env.local` do piano-app é o ponto único de troca de fonte — cache triplo precisa ser invalidado em cadeia (07/09/2026)**: Apontar o Electron pra API local (`http://127.0.0.1:3100/json_db` + `/file`) em vez de túnel efêmero é a receita de teste mais estável (ver pitfalls 59/60/64). MAS ao trocar a fonte de dados, o cache triplo precisa ser invalidado: (1) `sessionStorage` do renderer (morre com o processo — fechar o Electron resolve); (2) `~/.config/LouvorJA-PIANO/.sysdata/pt_categories.bin` — cache persistente do bridge desktop (`rm`, é a migrating-plain do `writeWorkspaceRecord`); (3) reload da página. Sintoma de cache esquecido: categoria nova não aparece ou JSON ainda vem da fonte antiga. E a ORDENação das categorias é CÓDIGO, não dados — `CATEGORY_ORDER` replicado em `library-catalog.ts` E `album-catalog.ts` (pitfall 63); dado novo não muda ordem sozinho.

68. **PR #52 (feat/dev-seed) fechou o gap Infantis/Doxologia na API — validar a FONTE antes de culpar o app (08/09/2026)**: commits `40cdbe3`/`196195b`/`9046ec6`/`bfe6dda` adicionam (a) migrations 016+017 idempotentes com catálogo completo 90101-90167 (durations reais, covers JPG reais, cross-lists intencionais, ordem da UI), (b) `fetch-on-miss` em `music_{id}` (importa do upstream quando não existe local, 404 upstream = "não existe"), (c) fallback em cascata `UPSTREAM_FALLBACK_API` (workers.dev) para fetch de JSON E mídia on-demand no `/file/*`, (d) 404 mirroring (upstream 404 → responde 404, não 502), (e) campo novo `has_playback` em `album_{id}`. **Sequência de validação E2E comprovada**: (1) `curl $TUNNEL/json_db/pt_categories?typ=db` → categorias 98/99 com albums; (2) `album_9010`/`album_9000` → `has_playback:true` + `url_image` populado; (3) `music_90141` → `lyric[]` com `id_lyric` + `url_music`/`url_instrumental_music`; (4) O TESTE QUE MAIS IMPORTA: `curl -o /dev/null -w "%{http_code} %{content_type} %{size_download}" $TUNNEL/file/musics/pt/90141.mp3` → `200 audio/mpeg ~2.3MB` (também testar `90141i.mp3` PB e covers). JSON listado mas mídia 404 = gap ainda aberto; tudo 200 = gap fechado, próximo passo é o app. **CI do PR pode falhar no Docker Smoke Test** (`/v1/health` não responde em 30s no container) — Quality Gate só propaga; lint/type/tests/build passam. Para testar piano-app contra o túnel: `.env.local` → URLs do túnel + `rm ~/.config/LouvorJA-PIANO/.sysdata/pt_categories.bin` (pitfall 67) + Vite porta própria 5175 + `env -u ELECTRON_RUN_AS_NODE VITE_DEV_SERVER_URL=http://127.0.0.1:5175 ./node_modules/.bin/electron .` via terminal background. Confirmar fonte no bundle: `curl http://127.0.0.1:5175/src/shared/services/workspace-api.ts | grep -oE "https://[a-z-]+\.trycloudflare\.com[^\"']*"`.

69. **CORP header de túnel Cloudflare bloqueia covers/áudio no Electron (08/09/2026)**: Túneis trycloudflare injetam `cross-origin-resource-policy: same-origin` e `cross-origin-opener-policy: same-origin` em TODAS as respostas — mesmo com `access-control-allow-origin: *`. CORP bloqueia subresource cross-origin no Chromium (renderer `127.0.0.1:5175` ≠ origin do túnel): console mostra `net::ERR_BLOCKED_BY_RESPONSE.NotSameOrigin` para covers/MP3 enquanto JSON (fetch com CORS) carrega. **Curl `-sI` não mostra o problema pro app** — curl ignora CORP; só o renderer bloqueia. Diagnóstico: checar os headers com `curl -sI` e procurar `cross-origin-resource-policy`. **Fix** (`<clone local do app>/electron/tunnel-corp-bypass.mjs`, registrado no `main.mjs` ao lado de `registerYoutubeEmbedHeaders()`): `session.defaultSession.webRequest.onHeadersReceived` com filter `*://*.trycloudflare.com/*` deletando os dois headers — filtro por host, produção não é afetada. Lição geral: **200 no curl ≠ mídia carrega no app**; validar headers de segurança (CORP/COOP/CSP) quando o recurso chega 200 via curl mas falha no renderer com ERR_BLOCKED_BY_RESPONSE.

70. **electron/main.mjs é CRLF — tool patch falha, editar em bytes**: O patch tool (fuzzy match) pode falhar ou sujar o arquivo. Editar via python lendo/gravando em bytes (`open(p,'rb')` / `.replace()` preservando `\r\n`) e confirmar com `grep -n` após a edição. Detalhes do Electron workflow: pitfalls 69/71/73 nesta skill.

71. **MP3 não toca no desktop mesmo com JSON ok: cadeia de 3 camadas no caminho de mídia desktop (08/09/2026)**: O pitfall 69 cobriu covers (CORP), mas o áudio tem uma camada EXTRA que o renderer não vê. Fluxo real do piano-app desktop: (1) `resolveMediaUrl()` (`workspace-api.ts`) retorna `local://media/...` quando `isDesktopApp()` — não usa VITE_URL_FILES; (2) `electron/protocol.mjs` (`registerLocalFileProtocol`) serve de `userData/Media` e em cache-miss baixa de `API_BASE_URL`; (3) o play do media store passa por `downloadTrackMedia` (`track-media.ts`) → `bridge.media.download` → `downloadMediaFile` (`electron/workspace.mjs`) → `buildApiMediaUrl()` que TAMBÉM usa o mesmo `API_BASE_URL`. **`API_BASE_URL` era hardcoded** em `electron/constants.mjs` (o caveat do pitfall 60) → oficial não tem 90xxx → download falha silencioso. **Fix**: `constants.mjs` agora aceita `PIANO_API_BASE_URL` env override; lançar o Electron com `PIANO_API_BASE_URL=<túnel>`. **Verificação**: `cat /proc/$(pgrep -f 'electron \.' | head -1)/environ | tr '\0' '\n' | grep PIANO_API`. Regra geral: main-process NÃO lê `.env.local` do Vite — toda constante do main que precisa de override dev-use precisa de env próprio. Sintomas de camada errada: covers carregam (renderer, CORP fix) mas MP3 não (main, API_BASE_URL); tudo falha = CORP; nada carrega = túnel morto ou fonte sem dados (pitfalls 59/64/68).

72. **Screenshot de janela Electron: todos os caminhos locais falham — validar por outros sinais**: `xwd -id`, `import -window id`, e screenshot da janela via cua-driver (pid+window_id) retornam PNG preto (GPU compositing). Screenshot do root pode pegar o monitor do JOGO (o PO joga Grounded 2 em outro monitor durante sessões dev) — olhar a imagem antes de concluir nada sobre o app. Caminhos de validação que funcionam: (a) console do renderer colado pelo usuário (foi assim que achou o CORP — pitfall 69); (b) `curl` do bundle do Vite greppando a URL da fonte; (c) arquivos baixados em `~/.config/LouvorJA-PIANO/Media/` (proxy de sucesso do download); (d) `/proc/<pid>/environ` para env do processo. Pedir confirmação visual ao usuário é o caminho honesto — não declarar sucesso sem evidência.

73. **Central de Mídia: faixa nova fora do cache local = "trackMissing" silencioso — leitor de catálogo SEM fallback remoto (08/09/2026)**: `loadMediaTrack()` em `src/modules/media/services/media-catalog.ts` lia SO de `readCatalogRecord()` (cache local `.sysdata/music_{id}.bin`). Faixa 90xxx nova nunca gravou `.bin` → `loadMediaTrack` retornava `null` → erro `trackMissing` ANTES de chegar em download/stream — nenhum erro de rede, nada em `Media/`, log limpo. **Fix**: fallback `fetchRemoteCatalogJson(`music_${musicId}`)` quando cache local é null — mesmo padrão que `track-media.ts:readMusicRecord()` já tinha. **Regra geral**: TODO leitor de catálogo novo no app precisa do par (cache local → fetch remoto); `readCatalogRecord` puro só serve para records que o bootstrap grava. Sintoma distintivo: "não toca" + ZERO arquivos novos em `Media/` + sem warn de download no log = falha ANTES do download (trackMissing); com warn `[track-media] falha ao baixar` = download (pitfall 71). Pendência da sessão: os 3 fixes (tunnel-corp-bypass.mjs, PIANO_API_BASE_URL em constants.mjs, fallback em media-catalog.ts) estão apenas locais em `~/piano-app` — commitar em branch feat com testes quando validado.

74. **Replicação de fonte alternativa cross-plataforma: só o Electron precisou de fix de código (08/09/2026)**: Ao levar as categorias/músicas novas (98/99, 90xxx) para os 3 alvos, NÃO portar os fixes do Electron automaticamente — cada plataforma resolve faixa nova de forma diferente: **Web** (`piano-web`): `loadMediaTrack` já usa `readOrFetchCatalogJson` (sessionStorage + fetch remoto embutido) — o fallback que o Electron ganhou é o comportamento padrão dela. Só precisa: `.env.local` com `VITE_URL_DATABASE`/`VITE_URL_FILES` do túnel + teste em aba anônima (sessionStorage/SW). **APK** (Flutter): `fetchMusic` → `_fetchJson('music_{id}')` é remoto direto (sem cache-first de record) + `DownloadUrlBuilder.build()` (fix 94019eb) — basta rebuild com `--dart-define=LOUVORJA_URL_DATABASE=<túnel>/json_db --dart-define=LOUVORJA_URL_FILES=<túnel>/file` (145MB release, ~40s de Gradle). **Electron**: os 3 fixes dos pitfalls 69/71/73. Regra de diagnóstico: verificar o fluxo de dados de CADA alvo antes de assumir que o bug replica — "não toca no app" não implica "não toca no web/apk", e vice-versa. Build APK embute o túnel no binário (pitfall 59) — é build de teste, não distribuição.

75. **Covers no piano-web bloqueadas pelo MESMO CORP do pitfall 69 — browser não stripa header, usar proxy same-origin no Vite (08/09/2026)**: Sintoma: web apontado pro túnel, JSON carrega, TODAS as covers falham (não só as novas). Causa idêntica ao Electron: Cloudflare injeta `cross-origin-resource-policy: same-origin`; no Electron resolve com strip de header, mas **browser não tem como remover headers de resposta de terceiros**. Solução comprovada no `piano-web/vite.config.ts`: `server.proxy` condicional — `env.VITE_DEV_MEDIA_PROXY ? { '/tunnel-file': { target: env.VITE_DEV_MEDIA_PROXY, changeOrigin: true, rewrite: p => p.replace(/^\/tunnel-file/, '/file') } } : undefined` + `.env.local` com `VITE_URL_FILES=/tunnel-file` e `VITE_DEV_MEDIA_PROXY=https://<túnel>`. O proxy repassa os headers CORP mas como o request agora é same-origin (`127.0.0.1:5173`), CORP same-origin não bloqueia. JSON do catálogo continua direto no túnel (fetch com CORS ok). Reiniciar o Vite após mudar vite.config (auto-restart acontece, confirmar porta livre). Triagem de console colado: `v-btn Failed to resolve` = import faltando (padrão do projeto é import explícito `{ VBtn } from 'vuetify/components'` — sem unplugin auto-import, componentes Vuetify não são globais); `contentscript.js`/`ObjectMultiplex`/`VM636` = extensão, ignorar.

77. **Sincronia projeção↔áudio: som só depois do bg+letra renderizados no receiver (08/09/2026, pedido explícito do o PO)**: O store de mídia (web/Electron compartilham `useMediaStore`) já publicava o runtime ANTES do `audio.play()`, mas o background-image do receiver só começava a baixar nesse instante — o som disparava com a tela ainda sem renderização (delay que o o PO tinha pedido antes era exatamente pra isso). Fix entre publish e play no `open()` do media store: (1) preload da capa via `new Image()` com onload/onerror e teto de 3s (nunca segurar o som mais que isso) — aquece o cache HTTP que a popup same-origin do operador reusa; (2) settle fixo de 400ms pro receiver aplicar bg+letra; falha de imagem NUNCA trava o play. **Padrão condicional > delay cego**: cacheado atrasa ~400ms, bg lento espera o necessário. **No APK não se aplica** (o APK é o próprio player, capa renderiza nativamente junto com o play — sem receiver separado). Ao repliar sincronização entre telas, lembrar: o receiver não tem ACK no protocolo — preload no operador + settle curto é o compromisso pragmático enquanto não existir handshake de "renderizei".

78. **CI vermelho pode ser dívida de commit anterior — checar o run do SHA anterior antes de culpar o próprio push (08/09/2026)**: PR #130 (web) já falhava Type Check desde o commit `8401199`: `resolveSlideImageUrl` e `resolveSlideIndexForTime` usados sem import + `params.options?.slots` (campo inexistente em `MediaOpenParams`). Meu push só empilhou em cima. **Primeiro passo ao ver CI vermelho**: `gh run list --branch <branch> --workflow CI` e comparar a conclusão do SHA anterior ao seu. Se já era vermelho, é dívida anterior — consertar e explicar a origem no commit (fix `4c0d9b5`: imports + `openPopupModule('media')` sem override, já que a assinatura real recebe options direto e o popup-routing resolve o slot pelo módulo). LSP diagnostics do patch tool pegou os erros na hora — usar como gate antes de pushar.

79. **Docker Smoke Test fail (health timeout): import ESM sem extensão .js — repro local antes de chutar (08/09/2026)**: PR #52 (api) falhava no Docker Smoke (`/v1/health` não responde em 30s) com lint/typecheck/testes passando. Causa: `importMusicOnMiss.ts` importava `from "./upstream"` (sem `.js`) — tsconfig `moduleResolution: bundler` NÃO reescreve extensões no output ESM; Node exige extensão explícita → `ERR_MODULE_NOT_FOUND` no boot do container → morre antes do server. tsx/vitest toleram (por isso dev/testes passam). **Regra**: imports relativos em repos que compilam pra ESM SEMPRE com `.js`. **Receita de debug** (fechou em ~10min): (1) repro local: `docker build -q -t piano-api:smoke . && docker run --rm -p 3100:3100 piano-api:smoke` (foreground pra ver o erro); (2) `docker logs` mostra o stack real; (3) comparar imports do dist: `docker run --rm piano-api:smoke grep -rn upstream /app/dist/routes/compat.js` (correto, com .js) vs `/app/dist/lib/importMusicOnMiss.js` (sem .js). Fix de 1 linha + commit direto na branch do PR (a org dá write ao `Piano-Louvor-JA`). O log do job do CI só mostra o timeout — o erro real só aparece rodando o container local.

76. **Slides de solfejo/pausa mostravam o TÍTULO da música no meio do hino — regra do projeto: eliminar (08/09/2026)**: O upstream tem estrofes "fantasma": `lyric: ""` + `url_image` de partitura (ex: `hasd_132B.jpg`) com `show_slide: 1` (ex: music_1 index 15). O `MediaProjectionView` caía no fallback `showTitle = isCover || (!lyric && title)` → renderizava o NOME da música no lugar do solfejo/pausa — confuso pra quem não conhece o hino. **Fix em 2 camadas, paridade literal em app E web** (mesmos arquivos `media-slides.ts` + `MediaProjectionView.vue`): (1) `buildMediaSlides` filtra slides `showSlide` com texto vazio (`.filter(slide => (slide.lyric ?? '').trim().length > 0)` após o filtro showSlide); (2) `showTitle = computed(() => runtime.isCover)` — título grande SÓ no slide de capa, sem fallback pra slide vazio residual. slideTimesSec/resolveSlideIndexForTime seguem funcionando pois os índices são recalculados sobre o array filtrado. Qualquer preferência de UX explícita do o PO sobre projeção (sem título no meio, sem fricção, sync bg↔som) é regra de classe: replicar em todos os catálogos/visualizadores que compartilham o runtime.

80. **Auditoria de CI de todas as PRs abertas da org: sequência que fechou o board verde (08/09/2026)**: `for r in api app web apk; do gh pr list --repo Piano-Louvor-JA/$r --state open ...; done` → `gh pr checks <n> --repo <r>` por PR → para o que falha: (a) `gh api repos/.../actions/jobs/<id>/logs | grep -E "error|exit"` (`--log-failed` às vezes vazio); (b) check SHA anterior (pitfall 78); (c) repro local (pitfall 79). Board 08/09: api#52 8/8 ✅ (após fix .js), web#130 5/5 ✅ (após fix imports), web#127 5/5 ✅, apk#51 7/7 ✅, app#163 15/15 ✅ (Release Validation 3 OS × 3 Electron); api#53 dependabot falha "Validate PR source branch" (base errada, esperado — recriar via UI do dependabot). PRs #50/#51 (api) sem CI real: só auto-label. **Armódio branch sem PR**: `feat/remote-palco-slots` (app) tinha pushes mas NENHUMA PR aberta — CI não rodava nela; criar com `gh pr create --base staging`. **Conflito ao criar PR**: `mergeStateStatus: DIRTY` → resolver local com `git merge origin/staging`, adotar a versão da staging em arquivo de workflow disputado (`git checkout --theirs`), rodar vue-tsc+vitest local antes de pushar. **Falhas de teste PRÉ-EXISTENTES na staging pura** (GeneralView i18n mock, windows-shared-acl icacls, receiver-regression): confirmar rodando na staging em worktree limpo antes de culpar os próprios commits — documentar como issue separada, não consertar no mesmo PR. **Última milha é gente**: após board verde, todas as PRs ficam `BLOCKED` só por `REVIEW_REQUIRED` do codeowner @ezequiasfonseca (branch protection proposital — processo acordado do o PO). Não burlar; avisar o usuário pra chamar o revisor.

81. **Dependabot mira `main` mas o fluxo da org é staging→main — fix estrutural é `target-branch` no dependabot.yml (08/09/2026)**: Os workflows "Validate PR source branch" da api bloqueiam PR→main que não venha da branch `staging`. Dependabot abre por default contra a default branch → PRs de dependência nascem erradas e conflitam (dependabot brancha de main, staging está à frente). **Fix duradouro**: adicionar `target-branch: staging` em CADA entry de `package-ecosystem` do `.github/dependabot.yml` (npm, pub, github-actions). PRs existentes: mudar base via `gh api -X PATCH repos/<org>/<repo>/pulls/<n> -f base=staging` (o `gh pr edit --base` silenciosamente falha com warning GraphQL) resolve o gate, MAS o dependabot branchou de main → `mergeStateStatus: DIRTY`. **Sequência que funciona**: (1) merge do PR do dependabot.yml; (2) comentar `@dependabot rebase` nas PRs antigas — ele recria sobre a base certa; ou fechar (o dependabot reabre com target novo no próximo ciclo). **Armadilha de execução**: verificar `git branch --show-current` ANTES de commitar mudanças de infra — nesta sessão o commit do dependabot.yml saiu na `feat/palco-slot-parity` por engano (checkout -B abortado deixou na branch errada); corrigir criando branch limpa de origin/main e `git show <commit>:<file>` pra extrair só o conteúdo.

82. **Release sem release notes: varredura e redação humanizada (08/09/2026, pedido do o PO)**: Varredura: `gh release list --limit 30 --json tagName` + para cada tag `gh release view --json body --jq '.body | length'` < 20 = sem notes. **Escrever como humano user-friendly** (pedido explícito): agrupar em "## Novidades" e "## Correções", uma bullet por feature na linguagem de QUEM USA (ex: "projeção abre sozinha ao tocar música na liturgia", não "refatora MediaOpenParams"), traduzir commits técnicos em benefício, mencionar comportamento visível (timer negativo pulsando, capa no player). `gh release edit <tag> --notes "..."` (+ `--latest` quando a Latest estiver errada). Releases draft antigas de manutenção: nota honesta curta apontando pra versão superior, sem inventar detalhes. Derivar conteúdo de `git log <tagAnterior>..<tag>` filtrando feat/fix (ignorar chore/version bumps).

83. **URL relativa no `VITE_URL_FILES` quebra o bg em receiver de outra origem (08/09/2026)**: O proxy same-origin do pitfall 75 usa base relativa (`/tunnel-file`), mas o runtime de projeção publicado via BroadcastChannel/relay é consumido por janelas que podem estar em OUTRA origem (TV cloud, receiver PWA) — elas resolvem `/tunnel-file/...` contra a PRÓPRIA origem → 404 → bg não aparece. Fix em `resolveRemoteFileUrl` (media-audio.ts): base relativa → absolutizar com `window.location.origin` antes de compor. Regra: **toda URL que entra no runtime publicado deve ser absoluta**; URLs relativas só são seguras em caminhos que nunca saem da janela do operador (ex: IPC download). Sintoma: bg/capa funciona no operador e na popup local, some na TV/slot remoto.

84. **Hostname de túnel pode responder SEM ser sua máquina — orfão redireciona pro upstream e mascara como "funcionalidade faltando" (10/09/2026)**: `.env.local` do piano-app apontava pro túnel `trusted-catalogue-sub-benchmark.trycloudflare.com` cujo `cloudflared` NÃO estava rodando localmente. O hostname ainda respondia (outro backend ou rota residual do Cloudflare), mas `/file/custom/...` dava 302 → `api.Piano-Louvor-JA.com.br` → 404, enquanto a API local :3100 servia o MESMO arquivo 200 audio/mpeg. Sintoma confunde com "custom não implementado" — o usuário chegou a levantar essa hipótese. **Diagnóstico em 3 passos**: (1) `pgrep -af cloudflared` (túnel vivo nesta máquina?); (2) curl do mesmo path na API local vs túnel comparando status + `url_effective` (o `-L` do curl revela o redirect pro upstream); (3) se local 200 e túnel 404, subir túnel novo (`cloudflared tunnel --url http://localhost:3100`, background + grep do hostname no log) e atualizar `.env.local` + restart do Electron (VITE_ é build-time). Túnel trycloudflare é EFÊMERO (pitfall 59) — este é o caso em que ele morre MAS o hostname engana.

85. **Import .slja: slide CAPA do arquivo NÃO vira estrofe — duplicava o título e deslocava a sincronia (10/09/2026)**: O .slja do Delphi traz `Slide:1` com `tipo=CAPA` (texto = nome da música em caixa alta). O `parseSlja` preserva o type, mas o importador (`onImportFile` em `MediaEditorView.vue`) gravava TODO slide com texto como estrofe. Na projeção: `buildMediaSlides` já gera a capa automática (order -1, nome da música) + a estrofe 1 importada repetia o título → slide duplicado → letra inteira deslocada em relação ao áudio. **Fix**: filtrar `slide.type !== 'CAPA'` antes de gravar (simétrico ao export, que marca `index === 0 → CAPA`). **Músicas já importadas antes do fix precisam de limpeza de dados**: localizar o lyric duplicado (texto ≈ nome da música, time ~00:01) e `DELETE /v1/custom/lyrics/{id}` — validar pós-fix avaliando `buildMediaSlides(loadCustomMusicTrack(id))` via CDP no renderer vivo. Validação DOM/estado do Electron via CDP funcionou com `websocket.create_connection(url, suppress_origin=True)` (sem isso o handshake dá 403 por origin; `--remote-allow-origins` dispensável). Debug de "projeção estranha" em música custom: comparar slides do store com os tempos do .slja original.

86. **Auth simples de coletâneas custom: dono via token de sessão opaco, SEM auth JWT completo (10/09/2026)**: Implementado login mínimo e-mail+senha em `/v1/custom/auth/{register,login,me,logout}` — PBKDF2 com `node:crypto` (ZERO dependências novas; não usar bcrypt/jsonp/jwt para v1). Token opaco de sessão (`generateSessionToken` = crypto.randomBytes 32B); o banco guarda SÓ o sha256 do token (`hashToken`) em `custom_sessions` — token puro existe apenas na resposta do login/register. Migrations 021 (users+sessions) e 022 (`owner_id` + `author_name` nas 3 tabelas custom; `owner_id NULL` = coletânea legado/pública). Middlewares: `optionalAuth` (popula `c.get('user')` se Bearer válido) e `requireAuth` (401 se ausente/inválido) em `src/v1/custom/auth.middleware.ts`. **Escritas exigem dono** (PUT/DELETE/POST collections/musics/lyrics/files/copy → 403 se não-dono, 404 se não existe); leitura permanece pública-global com flag computada `is_owner` (`(cc.owner_id = ?) as is_owner` só quando autenticado, `0` quando anônimo). **GET /collections: TUDO visível a todos** — primeira versão filtrava `WHERE owner_id IS NULL` quando anônimo, que escondia coletâneas criadas (oposto do caso de uso de compartilhamento comunitário); semântica correta = tudo público + flag de dono pra UI. Fluxo E2E de aceite validado por curl: register → login → criar coletânea autenticada (owner_id populado) → DELETE alheio dá 403, DELETE inexistente dá 404 → logout invalida token (204) → `me` com token morto dá 401. Pendências documentadas: testes unitários das ROTAS auth (só o service tem teste por enquanto).

87. **Paridade 3 plataformas do auth custom: cada alvo consome o MESMO contrato, não o mesmo código (10/09/2026)**: Replicar "coletâneas custom com dono" nos 3 alvos não é portar código — cada plataforma tem seu client próprio: **API** (esta, pitfall 86) emite token Bearer; **Web/Electron** (`~/piano-app`, branch `feat/custom-auth`): `auth-client.ts` com sessão no localStorage (`louvorja.custom.auth`), `authHeaders()` injetado em TODAS as chamadas de escrita do `custom-catalog.ts`, `MediaAccountBar.vue` no aside do editor, editor exige sessão pra criar coletânea (toast orienta); **APK Flutter** (`~/Piano-Louvor-JA-flutter/src`, repo `Piano-Louvor-JA/apk` — NÃO "mobile" como constava, branch `feat/custom-catalog`): v1 somente LEITURA (decisão: upload/edição fica no desktop, onde é a curadoria), `CustomCatalogApiImpl` com `CustomFetch` injetável (testes sem mockar Dio — Dio é classe concreta, `type '_FakeDio' is not a subtype of type 'Dio'`; injeção de função é o padrão testável) + `.withDio` pra produção, `CustomCollectionsPage` acessível por ícone grupos na AppBar da tab Hinos (rota `/hymns/custom`), download registra em shared_prefs. **Teste Flutter precisa `TestWidgetsFlutterBinding.ensureInitialized()` + `SharedPreferences.setMockInitialValues({})`** no setUp (plugin channel). 783 testes passando (780 pré + 3 novos). E2E de contrato: validar o mapper do APK consumindo a resposta REAL da API (python/curl com assert nos campos `id_collection`, `musics_count`, `is_owner`) em vez de screenshot — visão de imagem (vision_analyze) falhou em responder detalhes de UI 4x seguidas nesta sessão; DOM/Playwright e asserts de JSON são evidência confiável.

88. **Repo Flutter já tinha Git (contrário do registrado antes) e lints Go 1.22 em Dart**: `~/Piano-Louvor-JA-flutter/src` NÃO estava sem `.git` (estado anterior no registro estava errado) — origin = `https://github.com/Piano-Louvor-JA/apk.git` (usar `git remote -v` para confirmar antes de assumir; certificado: branch `feat/custom-catalog` criada e pushed com sucesso). Warnings normais do `dart analyze` em `lib/`: `unnecessary_underscores` (usar `(_, _)` em vez de `(_, __)` — Dart 3.7+ wildcard params), `use_build_context_synchronously` em código alheio. Inicializador de construtor com closure multiline quebra o parser do Dart — usar `factory` + método `static` helper (ex: `dioCustomFetch(dio)`) em vez de `: _field = (...) => ...` no initializer. `resolveFile` deve normalizar barra inicial (`/custom/audio/x.mp3` → strip antes de concatenar com `filesBaseUrl/`, senão `//` duplicada).

90. **Dev server com `--watch` (tsx watch) em edição intermediária = ReferenceError fantasma**: Durante edição multi-patch de um arquivo grande (`custom.routes.ts` + `custom.schemas.ts`), o `tsx watch` reiniciou no meio da sequência e carregou um estado onde o import de `RegisterSchema` ainda não existia → crash com `ReferenceError` que PARECIA erro real do código final. O `tsc --noEmit` e os testes no estado final passavam limpos — o arquivo estava íntegro, só o watcher tinha pego estado pela metade. **Regra**: ao ver erro de runtime do dev server durante/Logo após edições, PRIMEIRO validar o estado final (`npx tsc --noEmit` + testes) antes de "consertar" algo que não está quebrado; e para trabalho com muitos patches, subir o server sem watch (`npx tsx src/index.ts` em background) e reiniciar manualmente.

89. **Deploy produção no VPS Hostinger — estado real e fluxo de restore (10/09/2026)**: Produção RODA no VPS do Ezequias: `ssh usuario@servidor (srv1969455, Ubuntu 26.04, 48GB disco/3.8GB RAM — chave pública do o PO já cadastrada; host veio via Telegram "hostinger me passou ssh"). Projeto em `/opt/services/api-piano-louvorja` (clone git de `Piano-Louvor-JA/api`, branch `main`). Stack: Docker Compose — container `piano-api` (NÃO exposto no host; só `expose: 3100` na rede docker externa `proxy`) + container `caddy:2` (único com 80/443). Caddyfile em `/opt/caddy/Caddyfile`: `api.Piano-Louvor-JA.com.br → reverse_proxy piano-api:3100` (DNS já aponta pro VPS, TLS automático). **Diagnóstico pelo lado de dentro**: `docker exec caddy wget -qO- http://piano-api:3100/...` — curl do host dá 000 pois a porta não está publicada. Volumes: `./data:/app/data` e `./media:/app/media` (dados FORA do container — rsync direto no host persiste). **Restore de backup (comprovado)**: backup local em `/media/contribuidor/NovoVolume/piano-api-backup/` (data 298MB + media 18GB + code.tar.gz); fluxo: (1) `docker compose stop api` ANTES do rsync (evita corrida com WAL do SQLite); (2) `rsync -az --info=progress2` de data/ e media/ em background com notify; (3) `docker compose start api`; (4) validar `https://api.Piano-Louvor-JA.com.br/v1/health` (502 durante o stop é esperado). Disco do VPS comporta (45GB livres) — gargalo é o upload residencial (18GB = horas). Branches feature (ex: `feat/custom-auth`) só chegam em produção via merge main + rebuild do container — o VPS em main@1.1.0 não tem auth custom até o PR merge e `docker compose build`.

## Auth Custom (login simples — sessão 10/09/2026)

Ver pitfalls 86-88. Resumo executivo:

| Camada | Onde | Contrato |
|--------|------|----------|
| API | `/v1/custom/auth/*` (piano-api, branch `feat/custom-auth`) | PBKDF2 + token opaco sha256 no banco; `owner_id`/`author_name` nas 3 tabelas custom; escrita exige dono, leitura pública |
| Web/Electron | `~/piano-app` (branch `feat/custom-auth`) | localStorage session + `authHeaders()` em escritas; `MediaAccountBar.vue` no editor |
| APK | `Piano-Louvor-JA/apk` (branch `feat/custom-catalog`) | v1 leitura: `CustomCatalogApiImpl` (CustomFetch injetável) + `CustomCollectionsPage` (rota `/hymns/custom`) |

PRs pendentes de review Ezequias nas 3 branches. Registro completo no Obsidian: `04-Projects/PIANO/2026-09-10-auth-coletaneas-custom.md` (com evidência visual E2E em anexos). **Detalhes e receita E2E completa**: `references/2026-09-10-custom-auth-simple.md`.

91. **Bíblia ES: chave de capítulo usa offset +66 nos livros — testar com o bookId certo antes de concluir "ES não existe" (10/09/2026)**: A chave é `bible_{version}_{book}_{chapter}`; livros ES são ids 67–132 (Génesis=67). Testar `bible_10_1_1` (version 10 ES com book 1 PT) dá 404 e parece "ES sem capítulos"; o correto é `bible_10_67_1`. Descoberta contra-intuitiva: o mirror local (`data/bible_cache/`, 15.458 arquivos = 13 versões × 1189 caps) tem os capítulos ES **completos**, enquanto a produção do Mayco NÃO tem nenhum (`bible_10_*` → 404) — miss de ES nunca resolve no upstream. Gaps fechados em `a51c509`: `es_bible_book`/`es_bible_version` no compat.ts (DB quando populado, fallback espelhando a prod), bible_versions com SEV/RV/RVA. Mapeamento completo e receita de diagnóstico: `references/bible-catalog-mapping.md` e `docs/BIBLE_API.md` no repo. **Correção do o PO sobre autoria**: a piano-api é do MAYCO; Elias NÃO fez API nenhuma (é conteúdo/curadoria) — nunca atribuir endpoints/biblias ao Elias.

92. **PR com base errada (main) na org feat→staging→main: retarget + merge de staging no branch + validação local antes de push (10/09/2026, PR #68)**: PR #68 (feat/custom-auth) foi criada com base `main` — `mergeStateStatus: DIRTY` com **8 arquivos em conflito** (main avançou pra release 1.1.0); contra `staging` eram só 2. **Fluxo comprovado**: (1) retarget — `gh pr edit --base` falha silenciosamente com warning GraphQL de Projects classic (pitfall 81); usar mutation: `gh api graphql -f query='mutation { updatePullRequest(input: {pullRequestId: "<node_id>", baseRefName: "staging"}) { ... } }'`; (2) resolver conflitos de verdade fazendo `git merge origin/staging` NO branch feature (não só retarget — o GitHub continua DIRTY até o branch mergeável com a base); conflitos add/add em custom.routes/schemas: a versão do branch auth é a mais nova (descende de custom-media, pitfall 87) → `git checkout --ours` nos 2 arquivos; (3) **validar o merge ANTES de pushar**: `tsc --noEmit` + `npm test` no estado merged (148/148 passando) — só então commitar o merge e pushar; (4) CI pode falhar DEPOIS em `Lint & Format` (`biome ci src/ test/`) por `noExplicitAny` em ~24 pontos — a config biome da staging difere da do branch (a #67 passa com o mesmo arquivo); rodar EXATAMENTE o comando da CI local (`npx biome ci src/ test/`, não `check`) antes do push. Reproduzir conflito de PR localmente: `git checkout -b test/merge origin/<base> && git merge --no-commit origin/<feature> && git diff --name-only --diff-filter=U` — sempre abortar e deletar o branch de teste depois.

93. **Fakes de teste escondem bugs de integração real — o teste de widget com Dio REAL pegou bug que 780 testes não pegaram (10/09/2026, apk PR #54)**: `CustomCatalogApiImpl._decode()` só aceitava `Map`/`String`, mas o Dio real devolve `Response<dynamic>` — **a tela de coletâneas nunca carregou com Dio de verdade**, apesar de todos os testes passarem (os fakes `_FakeNet` devolviam Map puro, pulando a camada Dio). Fix: unwrap recursivo `if (raw is Response) return _decode(raw.data)`. **Lição de classe**: teste unitário com fake valida o mapper, NÃO a integração; para camada de rede, pelo menos um teste com `HttpClientAdapter` fake (Dio real + adapter que lança/retorna) cobre o gap — adapter injetável via `dio.httpClientAdapter = ...` não precisa de mock de Dio (classe concreta, ver pitfall 87). Teste de widget com Dio real pegou também o comportamento de erro: `DioException(connectionTimeout)` aparece na UI com `(${e.type.name})` — seam de teste: widget aceita `dio?` opcional + `buildDefaultDio()` `@visibleForTesting` (timeouts 8s/15s são contract testado). Catch genérico "Sem conexão" sem log da exceção = diagnóstico cego no logcat; SEMPRE logar tipo+mensagem antes de transformar em mensagem amigável.

94. **i18n de catálogos nos clientes: fallback por idioma precisa tratar 200-vazio, não só 404 (12/09/2026)**: O desktop tinha `pt_bible_book`/`pt_bible_version`/`pt_categories`/`pt_hymnal` HARDCODED em `bible-catalog.ts` e `liturgy-catalog.ts` (HYMNAL_SOURCES const) enquanto `album-catalog.ts` já usava `getCurrentApiPrefix()` — ao trocar pra ES, bíblia não mudava. Fix (app#175): montar filename com prefixo dinâmico + fallback pra `pt_` quando a API 404. **Gotcha descoberto depois**: a API pode responder **200 com array vazio** (`[]` — rota existe mas seed não rodou) e o fallback NÃO dispara (só 404 cai pra PT) → usuário vê lista vazia em vez de PT. **Regra**: no cliente, tratar `Array.isArray(x) && x.length === 0` igual a "não tem no idioma". O áudio ES funciona por causa de IDs distintos por idioma (hino 1 PT=1728, ES=2643) — `music_{idES}` já traz `url_music: /musics/es/...` (200). Cuidado: warnings `[bible] falha ao obter catálogo es_*` para 404 são caminho esperado — silenciar 404, logar só erros reais (o erro lançado é `Error("api-exhausted: 404")`, status vai na MENSAGEM, não como propriedade).

95. **Diagnóstico de produção no VPS: dados podem EXISTIR no SQLite e a rota não expor (12/09/2026, issue api#76 → PR #78)**: Sintoma "Bíblia ES não carrega" — `/json_db/es_bible_*` 404. Investigação via SSH (`ssh usuario@servidor mostrou que o banco de produção JÁ TINHA os dados (66 livros ES 'Génesis'..., 3 versões, 93.312 versículos em `bible_book`/`bible_version`/`bible_verse` com `id_language='es'`) — o que faltava era a ROTA: o handler compat servia de manifest de arquivos (`files` table = 0 registros bible), não das tabelas. **Receita de inspeção do container**: script JS via `docker cp` + `docker exec -w /app piano-api sh -c 'NODE_PATH=/app/node_modules node /tmp/x.js'` (NODE_PATH obrigatório — require não resolve de /tmp; `-w /app` sozinho não basta). Evitar heredoc com aspas no SSH — escrever arquivo local e scp. **Deploy ≠ merge**: container de produção pode estar com imagem ANTERIOR aos PRs mergeados (health reportava 1.1.0 com staging já em 1.2.0) — comparar versão do `/v1/health` com a release da staging antes de concluir "não propagou".

96. **502 em rajada curta durante deploy = Caddy sem backend — transitório, não bug (12/09/2026)**: `docker restart` do piano-api deixa o Caddy servindo 502 em TODAS as rotas (mesmo `/v1/health` e `pt_*`) por ~30-60s (`health: starting` no `docker ps`). O Ezequias reporta "problema de proxy" e o app parece "abaixo do fallback" — na verdade é só a janela de restart. **Diagnóstico em 1 comando**: `ssh usuario@servidor "docker ps --format '{{.Names}} {{.Status}}'"` → `Up N seconds (health: starting)` confirma; esperar e re-curl. Só investigar log de erro se persistir >2min (aí pode ser migration/import travando o boot — `docker logs piano-api --tail 20`).
