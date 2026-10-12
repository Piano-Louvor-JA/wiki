# LouvorJA API

> **Metodologia pública** — API oficial do LouvorJA (upstream, api.louvorja.com.br). Aplica-se a qualquer stack.

---
Load this skill when working on anything related to the LouvorJA project (louvorja/app).

**Catalog records por idioma (pt_/es_):** ver `references/catalog-records-by-language.md`

**Mídia reproduzível:** `references/media-assets-contract.md` — `url_music: null` = sem bytes; contrato files→musics.

**Auth custom + coletâneas + e-mails + painel admin (14/09):** ver `references/piano-custom-auth-email-admin.md`

**Roteamento do Palco por slot (WT-6A, 04/09):** ver `references/2026-09-04-wt6a-slot-routing.md` — contrato `?slot=N` + envelope `to: slot-N`, pitfall `PALCO_RELAY_KEY` (4404, fix `--env-file-if-exists`) e pitfall de E2E contra `dist` antigo.

**API dupla com IDs divergentes (28/08) — playlists só tocam com IDs da API que o .env aponta (90xxx nova ≠ 2104 antiga p/ mesma música); nunca inventar musicId; validação de JSON de playlist com probe /file:** ver `references/api-dual-ids-playlists-2026-08-28.md`

**Painel adm.louvorja.com.br + versionamento da API (louvorja/adm + louvorja/api):** ver `references/adm-api-mapping.md` — fluxo completo CRUD→version_number→JSONs estáticos, endpoints /db/manifest com hash MD5, padrão de sync eficiente pro dashboard.

**Mapeamento de paridade completo (63+ issues, 5 repos, ~160h):** ver `references/paridade-mapping-2026-08-06.md`

**API Própria Piano-Louvor-JA/api (NOVO):** Hono 4 + SQLite + Docker. Esforço ~33h. **Agnóstica** — Hostinger VPS (não VM Oracle). Ezequias gerencia deploy. Modelo de negócio: IASD grátis, CCB/outras denominações pago via X-License-Key. Ver `references/api-propria.md` para detalhes completos. Issues app#67-#80 + app#66 + web#82.

### Forks conhecidos da org louvorja

| Fork | Autor | Stack | Destaque |
|------|-------|-------|----------|
| `Piano-Louvor-JA/app` | PO (nosso) | Electron + Vue 3 + TS + Vite | Fork com design system proprio (PIANO) |
| `juanaleixo/louvorja` | Juan Aleixo | Electron + Vue 3 + Vuetify 4 + Pinia | **Mais avancado**: 31 modulos, SSE, power blocker, auto-updater, E2E tests, controle remoto completo |
| `corugo/louvorja` | Corugo | Electron + Vue 3 | Fork menor |
| `elvieira/LouvorJA` | Elvieira | Electron + Vue 3 + TS (branch `electron`) | **Infra robusta**: SQLite real (sql.js), AES-256-CBC, validador instalacao, download HTTP->FTP com mutex, multi-idioma DB, block DevTools producao, fundo preto + fade projecao. |
| `louvorja/desktop` | (original) | Delphi/Pascal | App original Windows-only (READ ONLY) |

**juanaleixo/louvorja** e o fork mais maduro. Ja implementou features alem do Delphi:
controle remoto com SSE (nao polling), power blocker, atalhos globais OS, overlays,
background sound, videos online, editor de slides, favoritos, historico, coletaneas
pessoais, auto-updater com beta channel, JSON cache, testes E2E (Playwright), CLAUDE.md.


## API Lumen — Info Tecnica

### Stack
- **Framework:** Lumen (micro-framework PHP, Laravel ecosystem — NAO tem `artisan route:list`)
- **Banco:** SQLite local (`database/database.sqlite`) em dev, MySQL em produção
- **Doc:** Swagger UI via swagger-php v4 (`/documentation`)
- **Cache:** `array` driver em dev

### Pitfall: PHP Built-in Server ignora .htaccess
O `php -S` NAO processa `.htaccess` — todas as requisições para paths que não correspondem a arquivos estáticos em `public/` retornam 404 direto do PHP, sem passar pelo Lumen (index.php).
**Fix:** Usar um `router.php` e subir com `php -S 0.0.0.0:<port> -t public public/router.php`.
O router.php serve arquivos estáticos quando existem e delega tudo mais ao `index.php`.
**Já existe em** `public/router.php` no repo. Exemplo de uso:
```bash
php -S 0.0.0.0:3001 -t public public/router.php
```
**Pitfall secundário:** `php -S localhost:PORT` só ouve em `127.0.0.1` (não acessível externamente). Usar `0.0.0.0:PORT` para aceitar conexões de fora.

### OpenAPI Spec
- Gerado por `php generate_openapi.php` → salva em `storage/openapi.json`
- Servido via `OpenApiController@spec` (rota `/openapi.json`)
- O controller injeta servers dinâmicos: dev (URL do request) + produção (`api.Piano-Louvor-JA.com.br`)
- Swagger UI em `/documentation` (HTML estático com CDN jsdelivr)

### Rotas e Estrutura
- Arquivo de rotas: `routes/web.php`
- Controllers: `HymnalController`, `CategoryController`, `AlbumController`, `CollectionController`, `DatabaseJsonController`, `TaskController`
- PR #28 adicionou rotação greedy-match: rotas estáticas (`/db/manifest`, `/db/bundle`) antes de rotas dinâmicas (`/db/{table}`) para evitar conflito
- `ApiMiddleware` corrigido: crash em `$request->limit` (accessor query/input lookup)

### Servir localmente
```bash
cd /home/ubuntu/dev/workspace/projects/louvorja-api
php -S localhost:3001 -t public   # ou porta 8081/8099
# Swagger UI: http://localhost:3001/documentation
```
**NOTA:** Usar `terminal(background=true)` pois `php -S` é long-lived. NAO usar `&` inline — Hermes bloqueia.

### Testes
- PHPUnit: `./vendor/bin/phpunit` (94/94 passando após PR #28)
- BD usa SQLite em dev — dados mínimos (1 album "Hinos da Harpa", 2 musicas)

### Portas na VM
- Porta 3001: pode ser usada para a API (Next.js Jornada no Deserto usa outra porta ou pode ser desligado)
- Porta 8081/8099: instancias PHP alternativas
- **NÃO confundir API (Lumen) com frontend (Next.js/Vue) — são projetos separados**

## Arquitetura Atual (07/2026)

### Org LouvorJa no GitHub (5 repos separados)

O projeto foi reestruturado da monorepo `elvieira/LouvorJA` (2 branches) para uma org com repos separados:

| Repo | Descrição | Stack |
|------|-----------|-------|
| `louvorja/app` | Frontend web (main branch) | Vue 3 + Vuetify 4 + Vuex 4 + Vite 7 + PWA |
| `louvorja/desktop` | App desktop (Electron) | Electron + Pinia + TypeScript + Vuetify 4 |
| `louvorja/api` | Backend API | — |
| `louvorja/site` | Site publico | — |
| `louvorja/adm` | Painel admin | — |

**CRITICAL — REPO CERTO:** O repo canônico é `elvieira/LouvorJA` (branch `main` para web, branch `electron` para desktop). O branch `electron` NÃO está disponível localmente — acessar via `gh api repos/elvieira/LouvorJA/git/trees/electron?recursive=1`. Ver `references/web-parity-modules-analysis-2026-07-06.md` para gap analysis detalhado de módulos.monorepo). As issues e todo trabalho DEVEM ser criados aqui. A org `louvorja/` (app, desktop, api, site, adm) é uma separação que EXISTE mas o Elias e o o PO trabalharam no `elvieira/LouvorJA`. **NUNCA criar issues em `louvorja/app` — SEMPRE em `elvieira/LouvorJA`.** Dentro desse monorepo, a pasta `/app` é a versão web e `/desktop` é a versão Electron.

**Permissões no repo `elvieira/LouvorJA`:** Piano-Louvor-JA tem permissão de issue (criar/fechar) mas NÃO de admin (não pode criar labels). Usar labels padrão do GitHub (`enhancement`, `bug`, etc.) ou prefixar scope no título.

**PR #49 (juanaleixo:main)** é um mega-PR CONFLICTING que tenta portar todo o desktop para dentro do repo app (Electron, Pinia, TS, Vuetify 4, 50K+ linhas). Status: CONFLICTING, nao mergeavel.

### louvorja/app — Modulos existentes

| Modulo | ID | Categoria |
|--------|-----|-----------|
| Biblia | bible | bible |
| Hinario Adventista | hymnal | musics |
| Hinario Adventista 1996 | hymnal_1996 | musics |
| Albuns (Coletaneas) | collections | musics |
| Musica | musics | musics |
| Album | album | — |
| Letra | lyric | — |
| Slide (Media) | media | — |
| Controle Remoto | remote_control | — |
| Temas | theme | — |
| Desenvolvedor | dev | — |
| **Relogio** | clock | utilities |
| **Cronometro** | stopwatch | utilities |
| **Counter** | counter | utilities |
| **Animacao** | animation | utilities |

### Roadmap: Paridade Web (Epic #66)

Elias decidiu (06/07/2026) deixar a versao web completa (nao mais "capada"):
- Importar modulos do desktop: Biblia (ajustes design), Relogio (redesign), Sorteio
- Responsividade mobile (layout adaptativo)
- Bloquear utilitarios (clock, stopwatch, counter, animation) em viewports mobile — mobile = so musica + Biblia
- Tela secundaria para projecao web (Presentation API)

### Pitfall historico (ANTIGO — pode ainda aplicar ao repo elvieira/LouvorJA)

O repo antigo tinha dois branches (`main` web, `electron` desktop). Feature branches para desktop SEMPRE deviam ser baseadas em `electron`. No novo layout, desktop e um repo separado (`louvorja/desktop`).

**FORK do o PO:** `Piano-Louvor-JA/elias-louvorja` — push PRs aqui quando sem acesso de escrita no original. Remoto: `fork` (adicionar via `git remote add fork git@github.com:Piano-Louvor-JA/elias-louvorja.git`). **ALWAYS** push para fork e criar PR de lá.

**`gh` alias quebrado:** O alias `gh` aponta para `rtk` (Rust tool). Usar `/usr/bin/gh` para GitHub CLI.

## Legacy Import — Migracao Delphi Desktop → Electron (PR #53)

Componentes adicionados para importar `database.db` do LouvorJA Delphi Desktop no primeiro boot do Electron:

| Arquivo | Função |
|---------|--------|
| `electron/LegacyImporter.js` | Classe `scan()`: busca `database.db` do Delphi via registry Windows, paths comuns, e diretório do exe. Windows-only (lazy require do registry). |
| `electron/main.js` | IPC handlers `scan-legacy-db` (detecta + retorna versao) e `import-legacy-db` (extract via DbExtractor + marca boot completo). |
| `electron/preload.js` | Expoe `scanLegacyDb()` e `importLegacyDb()`. |
| `src/layout/FirstBootLoader.vue` | UI: botoes "Importar do Desktop" / "Baixar da Internet" no primeiro boot. |

**Arquitetura:**
- `LegacyImporter.scan()` retorna path do `database.db` ou `{ found: false }`
- `import-legacy-db` chama `DbExtractor.extract(foundPath)` — **zero duplicacao** de extract/encrypt
- Add-only: dados importados sobrescrevem o estado limpo do primeiro boot
- Windows-only: scan silenciosamente ignorado em Linux/macOS (return `found: false`)
- Primeiro boot: `checkFirstBoot()` → `scanForLegacyDb()` → se encontrado: mostra opcao; se nao: `runFirstBootSync()` (FTP download normal)

**Pitfall:** NAO chamar metodos do component Vue via `window.electronAPI` — `fetchAndSave` é metodo local, nao IPC. Se precisar buscar config apos import, usar o proprio metodo do component.

## Fluxo de Download / Extração (Branch Electron)

```
┌─────────────────────────────────────────────────────────┐
│  Frontend (Vue 3 + Vite)                                │
│  localhost:5002 (npm run dev)                            │
└───────────────────────┬─────────────────────────────────┘
                        │  HTTP fetch + Api-Token header
          ┌─────────────▼─────────────┐
          │  Servidor de Dados API    │
          │  JSON (banco) + arquivos  │
          │  de mídia (imagens/áudio) │
          └───────────────────────────┘
```

**Arquitetura separada:** Frontend **não tem banco embutido**. Todos os dados vêm de servidor HTTP externo configurado via variáveis de ambiente.

## Arquitetura Electron (branch `electron`)

```
┌─────────────────────────────────────────────────────────┐
│  Renderer (Vue 3 + Vuetify)                              │
│  src/layout/, src/modules/, src/components/            │
└───────────────────────┬─────────────────────────────────┘
                        │  window.electronAPI (preload bridge)
          ┌─────────────▼─────────────┐
          │  Main Process              │
          │  electron/main.js          │
          │  IPC handlers (ipcMain)   │
          └───────┬─────┬─────────────┘
                  │     │
    ┌─────────────▼─┐ ┌─▼──────────────────┐
    │ DbExtractor   │ │ FTP Download       │
    │ (better-sqlite3)│ │ (basic-ftp)       │
    │ Lê database.db │ │ GET /params       │
    │ Extrai p/ JSON  │ │ Download DB       │
    │ .sysdata/*.bin  │ │                   │
    └────────────────┘ └───────────────────┘
```

### Ciclo de vida do DB no Electron

1. **Download FTP** → `database.db` salvo em `userData/downloads/`
2. **DbExtractor.extract()** → Lê SQLite → extrai tabelas → salva como `.sysdata/*.bin` (JSON cifrado AES-256-CBC)
3. **database.db DELETADO** após extração (não permanece no disco)
4. **Renderer** lê `.bin` via `Database.js` helper → cache em `sessionStorage` com prefixo `db:`

### IPC Handlers Principais (main.js)

| Handler | Ação |
|---------|------|
| `get-local-db` | Lista DBs locais disponíveis |
| `extract-local-db` | Executa DbExtractor.extract() |
| `download-database` | FTP download de database.db |
| `clear-all-data` | Remove .sysdata/ + cache |
| `sync-check-version` | Compara versão local vs remota (feat nova) |

### Preload Bridge (preload.js)

Expõe `window.electronAPI` com métodos que invocam IPC handlers via `ipcRenderer.invoke()`.

### Helpers do Renderer

| Helper | Registro |
|--------|----------|
| `$database` | Global property (plugin helpers.js) — lê .sysdata/*.bin |
| `$storage` | `src/helpers/Storage.js` — wrapper localStorage/sessionStorage |
| `$media` | Global property — `isMinimized()` |
| `$alert` | Global property — notificações |

## Detecção de Novas Músicas (feat sync-check-version)

### Fluxo Completo (Delphi → Electron)

```
Maintainer add songs → Configs::refresh() increments version_number
                     → Ftp::send_database() copies to version_number_ftp
                     → GET /params returns db_version = version_number_ftp

Electron: Footer mounted → sync-check-version IPC
         → DbExtractor.getLocalDbVersion() (from .sysdata/db_version.json)
         → GET /params?type=env → parse db_version
         → compare: hasUpdate = remoteVersion > localVersion
         → if true: show snackbar "Novas músicas disponíveis!"
         → user clicks "Atualizar" → downloadDatabase() → extractLocalDb()
         → extract() reads VERSAO_BD → saves to db_version.json
         → $storage.removeAll("db") → window.location.reload()
```

### Arquivos Envolvidos

| Arquivo | Papel |
|---------|-------|
| `electron/DbExtractor.js` | `readDbVersion()`, `saveDbVersion()`, `getLocalDbVersion()` |
| `electron/main.js` | IPC handler `sync-check-version` (GET /params + compare) |
| `electron/preload.js` | Expõe `syncCheckVersion()` |
| `src/layout/Footer.vue` | Snackbar + download + extract + reload |

### API: GET /params?type=env

Retorna texto plano com key=value por linha:
```
db_version=185
ftp_host=...
ftp_user=...
ftp_pass=...
```

Parse: split por `\n`, depois split por `=`. `db_version` = `version_number_ftp` no servidor.

### Pitfalls — Electron

- **database.db é deletado após extração** — qualquer dado que precise persistir (ex: VERSAO_BD) deve ser salvo em arquivo separado antes da extração
- **Não usar `write_file` em arquivo parcialmente lido** — se usou offset/limit no read_file, o write_file vai sobrescrever tudo. Use `patch` para mudanças incrementais
- **FTP é o download primário** — API tem rate limiting que quebrou produção (04/07/2026). REST migration é non-scope até o PR de rate limiting ser mergeado
- **`VERSAO_BD` não existia no Electron antes** — tabela `VERSAO` existe no SQLite Delphi mas nunca foi lida pelo app Electron

---

## Endpoints da API

### URL Base
- Produção: `https://api.louvorja.com.br/json_db`
- Local: `http://localhost:8000/json_db` (API local)
- Local: `http://localhost:7070/database` (servidor estático)

### Autenticação
Todos os endpoints requerem header `Api-Token` com o token obtido com o administrador.

### Endpoint Manifest (lista de JSONs disponíveis)

Existem DOIS endpoints de manifest — o legado e o novo:

**Legado (PR #3):**
```
GET /json_db
```
Retorna `{ files: [{ name, size }], total }`.

**Novo (DatabaseJsonController::manifest()):**
```
GET /db/manifest
```
Retorna array de objetos com `file`, `table`, `path`:
```json
[
  { "file": "album_1.json", "table": "album_1", "path": "/db/album_1" },
  { "file": "pt_musics.json", "table": "pt_musics", "path": "/db/pt_musics" }
]
```
**Escala total: 16.871 arquivos JSON** (82 albums, 2.509 musics, 14.268 bible chapters, 6 metadata + 6 pt_*).
Cache: 1h no manifest, 5min por pagina no `/db/{table}`.

**Pitfall:** O endpoint `/db/{table}` (sem .json) serve JSONs individualmente via `DatabaseJsonController::index()`. O endpoint `/json_db/{file}` (legado) tambem funciona. Ambos leem de `public/db/json/{table}.json`. Prefira `/db/` em codigo novo.

### Endpoint de Config (versão do DB)
```
GET /json_db/config
```
Retorna metadados e versão atual do banco de dados:
```json
{
  "version": "X.X.X",
  ...
}
```

### Endpoints de Arquivos JSON
Cada arquivo é acessível separadamente. O servidor adiciona `.json` automaticamente.

| Arquivo | Endpoint | Conteúdo |
|---------|----------|----------|
| `config.json` | `/json_db/config` | Metadados + versão |
| `pt_categories.json` | `/json_db/pt_categories` | Categorias de músicas |
| `pt_musics.json` | `/json_db/pt_musics` | Todas as músicas (index) |
| `pt_hymnal.json` | `/json_db/pt_hymnal` | Hinário Cantor Cristão |
| `pt_hymnal_1996.json` | `/json_db/pt_hymnal_1996` | Hinário Adventista 1996 |
| `pt_bible_book.json` | `/json_db/pt_bible_book` | Livros da Bíblia |
| `pt_bible_version.json` | `/json_db/pt_bible_version` | Versões bíblicas disponíveis |
| `bible_{version}_{livro}_{cap}.json` | `/json_db/bible_{version}_{livro}_{cap}` | Capítulo específico |
| `music_{id}.json` | `/json_db/music_{id}` | Letra de música específica |
| `album_{id}.json` | `/json_db/album_{id}` | Álbum específico |

### Endpoints de Mídia
```
GET /file/{path}
```
Retorna arquivos de mídia (imagens, áudios, etc.).

---

## Setup de Desenvolvimento
**FM: QUERO O APP EXPOSTO NA REDE LOCAL PARA ACOMPANHAMENTO AO VIVO.\nUse `--host 0.0.0.0` para expor na rede.\nURL: `http://<IP-VM>:5174`**

### Pré-requisitos
- Node.js 18+
- npm 9+

### Variáveis de Ambiente (.env)
```bash
cp env .env
```

| Variável | Descrição |
|----------|-----------|
| `VITE_URL_DATABASE` | URL base dos arquivos JSON do banco |
| `VITE_URL_FILES` | URL base dos arquivos de mídia |
| `VITE_API_TOKEN` | Token de autenticação (header `Api-Token`) |
| `VITE_APP_MODE` | `development` ou `production` |

### Opções de Execução

#### Opção 1 — API Online (mais simples)
```env
VITE_APP_MODE=development
VITE_URL_DATABASE=https://api.louvorja.com.br/json_db
VITE_URL_FILES=https://api.louvorja.com.br/file
VITE_API_TOKEN=<token obtido com o administrador>
```

```bash
npm install
npm run dev
```

#### Opção 2 — API Local
Clone e execute o repositório da API separado (porta 8000).
Veja `references/api-local-dev-setup.md` para setup completo (PHP 8.3, Composer, .env, mock JSONs, servidor).
```env
VITE_APP_MODE=development
VITE_URL_DATABASE=http://localhost:8000/json_db
VITE_URL_FILES=http://localhost:8000/file
VITE_API_TOKEN=<token>
```

#### Opção 3 — Servidor Estático Local (offline)
Usa `node/server.js` (porta 7070):
```env
VITE_APP_MODE=development
VITE_URL_DATABASE=http://localhost:7070/database
VITE_URL_FILES=http://localhost:7070
VITE_API_TOKEN=<token>
```

```bash
# Terminal 1 — servidor de dados (OPCIONAL, se usar API externa)
npm run files

# Terminal 2 — frontend (expor na rede local)
npm run dev -- --host 0.0.0.0

# O App estará disponível nos IPs da VM:
# Linux (IPs roteável interna Oracle): http://10.0.0.19:5174
# Tailscale: http://100.124.203.116:5174
# Para acessar externamente, use o IP da VM ou Tailscale.

**Dica — IP discovery:**
Use o commando abaixo na VM para descobrir IPs expostos:
```
hostname -I 2>/dev/null || ip -4 addr show | grep inet | grep -v 127.0.0.1
```

**IDEIA DO ELIAS — Database Bundle (30/06/2026):**
O Elias propôs resolver o problema de 16.871 fetchs no primeiro boot do Electron com um approach hibrido:

1. **Baixar UM arquivo de bundle** (zip com todos os JSONs) — como o Delphi faz com o `.db`
2. **Extrair e converter** no primeiro boot — gerar os `.bin` individuais que o programa ja espera
3. **Sem mudar a logica do app** — o Electron continua lendo os mesmos arquivos `.bin`, soh muda o processo de seed

**Estado:** Elias pediu a rota que o Delphi usa para baixar o database. Resposta: o Delphi NAO usa mais OneDrive (link retorna 404). A API hoje soh serve JSONs individuais via `/db/manifest` + `/db/{table}`.

**⚠️ CONSTRAINT CRITICA — API na org louvorja, depende de PR aprovado:**
Qualquer mudanca na API (louvorja/api) requer PR aprovado pelo Mayco. Isso inclui criar novos endpoints como `/db/bundle`. O o PO NAO é admin da org — só pode contribuir via fork + PR. Mayco aprova sozinho e PRs grandes ficam parados.

**Opcoes de implementacao CONSIDERANDO a constraint de PR na org:**
1. ~~**Endpoint novo na API** `GET /db/bundle`~~ — PRECISA de PR aprovado na org. Demora imprevisível.
2. **Bundle client-side no build do Electron (CI)** — No build time, baixar todos os JSONs via `/db/manifest` e empacotar num zip asset que vai dentro do instalador. **SEM depender da API.** Gera asset estático no CI do elvieira/LouvorJA.
3. **Bundle em CDN/cloud storage independente** — Servir o zip via CDN próprio (Cloudflare R2, GitHub Releases asset). **SEM depender da API.** Atualizar o zip periodicamente via script/cronjob.
4. **Paralelismo com retry inteligente no FirstBootLoader** — Sem bundle: melhorar o processo existente com requests em paralelo (50-100 concurrent) + exponential backoff. Reduz de 16.871 requests sequenciais para ~170 batches paralelos.

**Recomendacao:** Opcao 2 (bundle no CI) ou opcao 4 (paralelismo). Ambas resolvem SEM depender de PR na org louvorja. A opcao 2 eh a que mais se alinha com a ideia original do Elias (1 download só).

**Seed dos JSONs mockados (baixar da API UMA VEZ):**
Usar o endpoint `GET /db/manifest` para descobrir todos os 16.871 arquivos, depois baixar via `GET /json_db/{table}` com rate limit respeitoso (~10 concurrent, 50ms delay). Ver `references/dev-seed-strategy.md` para script Python async pronto para uso.

**Estrutura esperada em `files/`:**
```
files/
├── database/
│   ├── config.json
│   ├── pt_categories.json
│   ├── pt_musics.json
│   ├── pt_hymnal.json
│   ├── pt_hymnal_1996.json
│   ├── pt_bible_book.json
│   ├── pt_bible_version.json
│   ├── bible_{id_version}_{id_livro}_{capitulo}.json
│   ├── music_{id}.json
│   └── album_{id}.json
└── <arquivos de mídia>
```

---

## Convenção de Issues no `elvieira/LouvorJA`

O repo usa prefixos no título para diferenciar scope de plataforma:

| Prefixo | Significado | Exemplo |
|---------|-------------|---------|
| `[Web]` | Feature/fix para a pasta `/app` (Vue 3 + Vite + PWA) | `[Web] Responsividade mobile` |
| `[Paridade]` | Feature do desktop que precisa ser portada para web | `[Paridade] Bíblia completa` |
| Sem prefixo | Geral, cross-platform, ou desktop | `feat: Observabilidade` |

**PITFALL — NÃO criar issues em `louvorja/app`!** O repo correto é `elvieira/LouvorJA`. Se criar no lugar errado, fechar com `not planned` e recriar no repo certo.

## Decisões do Elias (06/07/2026 — via Telegram)

### Paridade Web Completa
A ideia original era web "capada" (só Hinário + Coletâneas + Bíblia). Como alguém se disponibilizou a ajudar na web, a decisão do Elias é **deixar a versão web completa** junto com a desktop. Módulos a portar: Bíblia (com ajustes de design), Relógio (redesign feito), Sorteio.

### Mobile com Escopo Reduzido
Em viewports mobile (max-width 768px), o app DEVE bloquear utilitários (clock, stopwatch, counter, animation). Mobile = **só música + Bíblia**. Funcionalidades completas no desktop ou web desktop. Mostrar tooltip/banner indicando acesso completo via computador.

### Projeção Web — Tela Secundária
Na web, a projeção deve detectar tela secundária via Presentation API (`navigator.mediaDevices.getDisplayMedia()`). Fallback: abrir em nova aba/popup fullscreen. Desktop usa `BrowserWindow` do Electron no monitor secundário.

## Scripts Disponíveis

| Comando | Descrição |
|---------|-----------|
| `npm run dev` | Frontend dev server (porta 5002) |
| `npm run files` | Servidor de arquivos estáticos (porta 7070) |
| `npm run build` | Build de produção |
| `npm run serve` | Preview do build |
| `npm run host` | Expor na rede local |
| `npm run lint` | Verificar código com ESLint |

---

## Integração com Electron — Download do Banco

A API **não retorna todos os arquivos em um único endpoint**. Para atualizar o banco no Electron, baixe cada arquivo individualmente:

```javascript
const DB_FILES = [
  'config',
  'pt_categories',
  'pt_musics',
  'pt_hymnal',
  'pt_hymnal_1996',
  'pt_bible_book',
  'pt_bible_version'
];

async function downloadDatabase(apiUrl, apiToken) {
  const db = {};
  
  for (const file of DB_FILES) {
    const response = await fetch(`${apiUrl}/${file}`, {
      headers: { 'Api-Token': apiToken }
    });
    
    if (!response.ok) {
      throw new Error(`Failed to download ${file}: ${response.statusText}`);
    }
    
    db[file] = await response.json();
  }
  
  return db;
}

// Uso
const db = await downloadDatabase(
  'https://api.louvorja.com.br/json_db',
  process.env.API_TOKEN
);

// Verificar versão
const localVersion = localStorage.getItem('louvorja-db-version');
const remoteVersion = db.config.version;

if (remoteVersion !== localVersion) {
  // Atualizar banco local
  saveToLocal(db);
  localStorage.setItem('louvorja-db-version', remoteVersion);
}
```

### Download Sob Demanda (músicas individuais)

Para economizar bandwidth, baixe apenas as músicas que o usuário acessar:

```javascript
async function downloadMusic(musicId, apiUrl, apiToken) {
  const response = await fetch(`${apiUrl}/music_${musicId}`, {
    headers: { 'Api-Token': apiToken }
  });
  
  if (!response.ok) {
    throw new Error(`Failed to download music ${musicId}`);
  }
  
  return await response.json();
}
```

---

## Problemas Comuns

### "Arquivo de dados não encontrado!" ao abrir o app

Em modo development, o alerta exibe detalhes extras:
```
[DEV] Falha ao carregar: pt_bible_book
URL: http://localhost:7070/database/pt_bible_book
Verifique:
• O arquivo .env existe e tem VITE_URL_DATABASE definido
• O servidor de dados está rodando (npm run files ou API local)
• O arquivo pt_bible_book.json existe no servidor
```

**Causas em ordem de probabilidade:**
1. `.env` não encontrado — `cp env .env`
2. Vite não reiniciado após criar/editar `.env` — pare e reinicie `npm run dev`
3. `VITE_API_TOKEN` vazio
4. Servidor de dados não rodando
5. Arquivo específico ausente no servidor local
6. Porta 7070 ocupada (AnyDesk usa essa porta por padrão)

### Porta 7070 em uso (Windows)

```powershell
netstat -ano | findstr ":7070"
# anote o PID e verifique:
Get-Process -Id <PID>
```

Encerre o AnyDesk ou mude a porta em `node/server.js` e `.env`.

### App não atualiza após mudar o banco

JSONs são cacheados no `sessionStorage` com chave `db:<nome>`. Para forçar recarregamento:
- DevTools → Application → Session Storage → limpar
- Ou feche e reabra a aba

---

## Stack Tecnológica

| Tecnologia | Versão | Nota |
|------------|--------|------|
| Vue 3 + Options API | ^3.5.29 | JS puro, SEM TypeScript, SEM `<script setup>` |
| Vuetify 4 | ^4.0.0 | UI framework |
| Vuex 4 | ^4.0.2 | Estado global (NAO Pinia) |
| Vue I18n | ^11.x | PT/ES |
| Vite 7 | ^7.x | Build + dev server (porta 5002) |
| Electron | ^34.x | Target desktop (opcional) |

---

## API Backend (louvorja/api)

**Framework:** Laravel Lumen (PHP 100%) — **NAO** Node/Express.
**Repo:** https://github.com/louvorja/api
**Swagger/OpenAPI:** PR #25 (feat/swagger-docs-all-endpoints) adicionou OA\Attributes PHP 8 em 14 controllers com 59 paths documentados em 15 tags. Swagger UI em `/documentation`, OpenAPI JSON em `/openapi.json` (+ fallback `/api-spec`). Security scheme Bearer JWT. Global annotations em `app/OpenApi/Annotations.php`. **Dynamic server URL:** `OpenApiController::spec()` detecta protocol+host do request em runtime (nao hardcodeado), sempre inclui producao como server alternativo no dropdown. CORS em prod confirmado (`Access-Control-Allow-Origin: *`). **Status: PR aberto, 11+ commits pushed (dynamic server URL, absolute spec URL, download logic restored, .gitignore fix for spec deploy, /tasks/send_database_ftp route registration, README sync, CORS redirect documentation, GeneralMiddleware dev tunnel whitelist, Cloudflare Quick Tunnel sharing), aguardando Mayco. All 74 endpoints smoke-tested against production — 100% pass. Dev tunnel at `https://*.trycloudflare.com/documentation` for ephemeral sharing without exposing VM IP.** **Dev local:** Spec pre-gerada em `storage/openapi.json` (NÃO em `public/` — PHP built-in server serve `.json` como estático, bypassando Lumen). Regenerar com `php generate_openapi.php`. Dev server: `php -S 0.0.0.0:8080 -t public public/index.php` (porta 8080 liberada no UFW). **CRITICAL:** incluir `public/index.php` como router script — sem ele, `.json` e servido como estatico. Swagger UI em `http://137.131.142.73:8080/documentation` (dropdown tem "Dev" e "Producao" — selecionar Producao para testar API real sem DB local). Ver `references/swagger-openapi-pattern.md` para padrao completo, pitfalls, inventario de 59 paths, cross-validation script, e smoke test com curl.

### Controllers principais (auditado do fork local em 2026-06-23)

Controllers que REALMENTE existem no `app/Http/Controllers/` — TODOS com Swagger annotations (PR #25):

| Controller | Metodo(s) | Rota(s) | O que faz |
|------------|-----------|---------|-----------|
| `DatabaseJsonController` | `manifest()` | `GET /json_db` | Lista JSONs disponiveis com name + size (PR #3) |
| `DatabaseJsonController` | `index()` | `GET /json_db/{file}` | Le `public/db/json/{file}.json` e retorna como JSON |
| `DownloadController` | `index()` | `GET /download`, `GET /{lang}/download` | Informacoes de download |
| `MetaController` | `index()` | `GET /meta` | Metadados da Biblia (versoes, versiculos faltantes) |
| `PlayerController` | `index()` | `GET /player?v={id}` | HTML inline com YouTube embed iframe |
| `FileController` | `index()` | `GET /files` | Lista arquivos (PAGINADO via Data::data) — **SQL INJECTION aki** |
| `FileController` | `show()` | `GET /files/{id}` | Metadata de arquivo especifico |
| `FileController` | `open()` | `GET /file/{path}` | Serve arquivo fisico (imagem/audio) — regex route `{path:.*}` |
| `AuthController` | `login()` | `POST /auth/login` | JWT login (username + password) |
| `AuthController` | `me()` | `GET /auth/me` | Usuario atual |
| `AuthController` | `refreshToken()` | `POST /auth/refresh` | Refresh JWT |
| `AuthController` | `logout()` | `POST /auth/logout` | Invalida token |
| `AuthController` | `changePassword()` | `PUT /auth/change-password` | Troca senha |
| `MusicController` | `index()` | `GET /musics` | Lista musicas (paginado via Data::data) |
| `MusicController` | `show()` | `GET /musics/{id}` | Musica especifica |
| `ConfigController` | `index()` | `GET /{lang}/config`, `GET /{lang}/configs` | Configs publicas (auto-refresh diario) |
| `ConfigController` | `configs()` | `GET /{lang}/configs` | Alias para index — mesma logica |
| `TaskController` | `index()` | `GET /tasks` | Lista tarefas disponiveis |
| `TaskController` | `refresh_files_size()` | `GET /tasks/refresh_files_size` | Atualiza tamanho de arquivos |
| `TaskController` | `refresh_files_duration()` | `GET /tasks/refresh_files_duration` | Atualiza duracao de arquivos |
| `TaskController` | `refresh_online_videos()` | `GET /tasks/refresh_online_videos` | Atualiza videos do YouTube |
| `TaskController` | `refresh_configs()` | `GET /tasks/refresh_configs` | Refresh de configuracoes |
| `TaskController` | `export_database_json()` | `GET /tasks/export_database_json` | Exporta banco para JSON |
| `TaskController` | `export_database()` | `GET /tasks/export_database` | Exporta banco para SQL |
| `TaskController` | `send_database_ftp()` | `GET /tasks/send_database_ftp` | Envia exportacao via FTP |
| `TaskController` | `import_slides()` | `GET /tasks/import_slides` | Importa slides |
| `VersionController` | `index()` | `GET /version` | Versao API, PHP, Lumen, min_client_version (PR #16) |

**Controllers adicionais (auditados 2026-06-23):** CategoryController, AlbumController, LyricController, LanguageController, VersionLogController, HymnalController, CategoryAlbumController, AlbumMusicController, ConfigController, TaskController, OnlineVideosController, FtpController, ParamsController, OpenApiController — todos com CRUD e/ou endpoints dedicados. Ver controllers table abaixo para detalhes completos.

### Tasks administrativas (`/tasks/` prefix)

| Rota | Purpose |
|------|---------|
| `/tasks/export_database_json` | Exporta banco para JSON (gera os arquivos em `public/db/json/`) |
| `/tasks/generate_static_jsons` | Static JSONs com hash/ETag para offline (PR #28, `GenerateStaticJsons` helper) |
| `/tasks/export_database` | Exporta banco para SQL |
| `/tasks/refresh_configs` | Refresh de configuracoes |
| `/tasks/refresh_files_size` | Atualiza tamanho de arquivos |
| `/tasks/refresh_files_duration` | Atualiza duracao de arquivos |
| `/tasks/refresh_online_videos` | Atualiza videos do YouTube |
| `/tasks/send_database_ftp` | Envia exportacao via FTP |
| `/tasks/import_slides` | Importa slides |
| `/tasks` | Lista tarefas disponiveis |

### Middleware layers (auditado 2026-06-21, tunnel fix 2026-06-23)

Ordem de execucao em `bootstrap/app.php`:

```
CorsMiddleware          → CORS headers (Allow-Origin: * — PROBLEMA em prod)
GeneralMiddleware       → Bot blocking, subdomain redirect
ApiMiddleware           → Header Api-Token validation contra env('API_TOKEN')
LangMiddleware          → Idioma
Authenticate (JWT)      → JWT guard (rotas autenticadas)
AccessMiddleware        → Permissoes por role (insert/update/delete)
ConfirmedPasswordMiddleware → Exige troca de senha se temporaria
```

NOTA: `ApiMiddleware` define limite 100 mas NAO implementa throttling. Rate limiting adicionado via `RateLimitMiddleware` (PR #13, commit `7effb79`) — Cache-based IP throttle com headers X-RateLimit-*. **BUG CRITICO CORRIGIDO:** `->header()` crashava com `StreamedResponse` — fix via `->headers->set()` (PR #26, Elias corrigiu manualmente em prod). **PR #27 ajustou limites diferenciados por tipo de rota:** geral 300/min, arquivos 600/min, metadados 600/min (antes era 60/min fixo para tudo). Variaveis: `RATE_LIMIT_MAX`, `RATE_LIMIT_FILE_MAX`, `RATE_LIMIT_METADATA_MAX`, `RATE_LIMIT_DECAY`. Rotas `/file/` e `/player` usam limite alto (capas, slides, musicas batch downloads do desktop). Rotas `/version`, `/version_log`, `/metadata` usam limite medio-alto. PR #20 adicionou suporte a multiplas API keys com labels e hash_equals timing-safe comparison no proprio ApiMiddleware. Config logging adicionado em PR #19 (Monolog channels) mas ainda nao registrou `$app->configure('logging')` — isso foi feito apenas na branch feat/structured-logging. Em main, NAO existe `config/logging.php`.

### Padrao para criar novos endpoints de dados

Nao precisa codigo novo se for JSON estatico: basta colocar `{nome}.json` em `public/db/json/` — o `DatabaseJsonController` serve automaticamente via `GET /json_db/{nome}`.

Para snapshot dinamico (bundle de N arquivos), duas opcoes:
1. **Estatico:** Task gera `snapshot.json` em `public/db/json/` — endpoint ja existe
2. **Dinamico:** Nova rota no `routes/web.php` + controller que le os N arquivos e monta bundle on-the-fly

### Testing Patterns (PHPUnit)

The repo originally had NO tests. All existing tests were written by o PO/Hermes. PHPUnit 10 with Lumen testing.

- **Test location:** `tests/Feature/` (NOT Unit — Lumen's `app()` helper requires bootstrapping, so Unit tests fail when calling helpers that use `app()->basePath()`)
- **TestCase base:** `tests/TestCase.php` extends `Laravel\Lumen\Testing\TestCase` with `createApplication()` loading `bootstrap/app.php`
- **phpunit.xml:** Cache driver = `array`, DB = in-memory SQLite (`:memory:`)
- **Pattern for DatabaseJsonController tests:** Create fixture JSONs in `base_path('public/db/json/')` during setUp, clean up in tearDown. Use unique table names in test fixtures to avoid collisions between test classes (e.g., `etag_musics.json` not `musics.json` which is used by DatabaseJsonControllerExportTest)
- **Lumen ResponseFactory gotchas:** `response()->noContent(304)` does NOT exist in Lumen — use `response('', 304)` instead
- **Lumen's `$this->get()` vs `$this->call()`:** Use `$this->call('GET', ...)` when you need to set custom headers (e.g., `HTTP_If-None-Match`)
- **Existing test files:**
  - `DatabaseJsonControllerTest.php` — manifest + table basic tests
  - `DatabaseJsonControllerExportTest.php` — export endpoint tests
  - `OpenApiTest.php` — Swagger OA annotation validation
  - `GenerateStaticJsonsTest.php` — getHash, meta envelope
  - `StaticJsonTableETagTest.php` — ETag headers, 304 cache, meta extraction
  - `StaticJsonTaskTest.php` — /tasks/generate_static_jsons endpoint

### Pontos de atencao (pitfalls)

- Nao ha CI configurada nos PRs do `louvorja/app` (so deploy no push pra main)
- **CI/CD no GitHub Actions NÃO deve ser sugerido como PR** no repo `louvorja/api` (Mayco provavelmente roda CI fora da plataforma — assim como o o PO faz. Sugerir CI/CD como contribuição pode ser mal recebido). **Pular esse item do backlog do louvorja/api.** **NO ENTANTO, para o repo `elvieira/LouvorJA` (Electron), CI/CD É relevante** — o Elias não tem infra de build e precisa de workflow multi-plataforma. Issue #3 já foi criada sugerindo isso.
- **Telegram messaging NÃO automático** — só enviar mensagem no grupo de devs (-1002108908408) quando o usuário pedir EXPLICITAMENTE. Nunca mandar por conta própria após completar tarefas ou aberturas de PR. O usuário avalia quando é o momento certo de comunicar.
- **Lumen `response()->noContent(304)` NÃO existe** — o método `noContent()` pertence ao HTTP Client, não ao ResponseFactory do Lumen. Usar `response('', 304)` para retornar 304 Not Modified.
- **`jsonDir()` trailing slash** — `app()->basePath('public/db/json')` retorna sem `/` no final. Concatenar diretamente com filename (ex: `self::jsonDir() . $filename`) produz path errado (`public/db/jsonmusics.json`). Sempre garantir trailing slash ou usar `rtrim()` + concat com `/`.
- **JSON envelope `_meta` + `data`** — Os JSONs gerados pelo `GenerateStaticJsons` usam envelope `{"_meta": {"hash": "...", "generated_at": "..."}, "data": [...]}`. O campo `data` está em `$data['data']` (nivel raiz), NÃO em `$data['_meta']['data']`. Cuidado na extração no controller.
- **Test fixture isolation** — Quando múltiplos test files criam JSONs no mesmo diretório (`public/db/json/`), usar nomes de tabela únicos (prefixo `etag_`, etc.) para evitar colisão entre setUp/tearDown de classes diferentes.
- ~~A API nao tem Swagger/OpenAPI~~ **PR #25 adicionou OA\Attributes em todos os 22 controllers.** Swagger UI em `/documentation`, spec em `/openapi.json`. Pode usar Orval com essa spec.
- O `files` resource tem CRUD comentado no routes e referencia errada (`AlbumController` em vez de `FileController`)
- **SQL INJECTION CRITICO:** `FileController::index()` linhas 20-27 usa `whereRaw` com concatenacao direta de `$request["id_album"]`. Fix planejado no SDD PLAN Fase 2 (PR #5).
- ~~**SSL Verify desativado:** `TelegramService` e `YoutubeService` usam `verify: false` em localhost — em prod deve estar ativo~~ **FIXED no PR #14** — `config/files.php` agora defaulta `ssl_verify` para `true`; `YoutubeService` unificado para usar `config('files.ssl_verify')` em vez de hack de `isLocalhost`.
- **CORS wildcard:** `CorsMiddleware` envia `Access-Control-Allow-Origin: *` em todos ambientes
- **Testes:** 80 testes, 199 assertions (PHPUnit 10 + SQLite in-memory `DB_SQLITE_DATABASE=:memory:`). CRITICAL: Lumen `$this->get()` retorna `$this` — usar `$this->seeStatusCode()`. CRITICAL: `php-open-source-saver/jwt-auth` RouteParams.php causa 500 em rotas com middleware auth (veja `references/phpunit-lumen-setup.md`). Veja `references/phpunit-lumen-setup.md` para todos os pitfalls.
- **env() extensivo:** ~~Toda codebase usa `env()` diretamente no codigo — quebra com `php artisan config:cache`~~ **FIXED no PR #10** (36 chamadas substituidas por `config()`, novos arquivos `config/api.php` e `config/files.php`). Agora compatível com `config:cache`.
- ~~**Data.php tem debug comentado:** Linhas 34-35 tem `//echo $data->toSql()` — remover~~ **FIXED no PR #15** — dead code removido.
- ~~**Handler.php dead code:** Re-criava exceptions dentro if/elseif sem usar, `Response::$statusTexts` nao-fiavel~~ **FIXED no PR #18** — Handler refatorado com metodos dedicados, mensagens PT-BR padronizadas, debug-safe (5xx sem leak em prod).
- **config('jwt') deve ser registrado no bootstrap/app.php** — sem `$app->configure('jwt')`, o `config:cache` nao carrega as configs JWT e blacklist pode falhar. Adicionado na PR #17.
- **JWT RouteParams incompatibilidade com Lumen test env** — `php-open-source-saver/jwt-auth` `Http/Parser/RouteParams.php` linha 34 chama `$route->parameter()` assumindo objeto Route, mas Lumen emite array. Resultado: 500 ao bater rotas com middleware `auth` no test env. Workaround: testes usam `assertNotEquals(200)` para aceitar 401/500/503.
- **`->header()` no Symfony: depende do tipo de Response.** `Illuminate\\Http\\Response` (Laravel wrapper) tem `->header()` via trait. Mas `Symfony\\Component\\HttpFoundation\\StreamedResponse` (criada por `response()->stream()`) **NUNCA** teve `->header()` — esse metodo so existe em `Response` e `JsonResponse`, nao nas subclasses `StreamedResponse` e `BinaryFileResponse`. O metodo correto para TODAS as versoes e `$response->headers->set()`. **Pitfall CRITICO:** quando um middleware chama `->header()` em `$response = $next($request)`, o tipo da response depende do controller — pode ser JsonResponse, StreamedResponse, etc. Se for StreamedResponse, crash com `Call to undefined method`. **CORRECAO FACTUAL:** Nao e especifico do Symfony 8.x. `StreamedResponse` nunca teve `->header()` em nenhuma versao do Symfony (5.x, 6.x, 7.x). O bug existe desde que o RateLimitMiddleware foi adicionado, mas so se manifesta quando o controller retorna StreamedResponse (rota `/file/{path}`).
- **Bug de download de arquivos (29-30/06/2026) — RESOLVIDO:**
  - **Sintoma:** `GET /file/covers/*.bmp` e `GET /file/musics/**/*.mp3` retornavam HTTP 500 com body `{"error":"Call to undefined method Symfony\\Component\\HttpFoundation\\StreamedResponse::header()","code":500}`. 4 sintomas: covers 500, mp3s 500, banco download 500, NotSupportedError de audio no Desktop (consequencia).
  - **Causa raiz:** `RateLimitMiddleware` (commit `7effb79`, mergeado no main) chamava `->header()` chain em `$response`. Quando `FileController@open` retornava `StreamedResponse`, crash.
  - **Fix PR #26:** Branch `fix/rate-limit-streamed-response` (fork Piano-Louvor-JA/api). Troca `->header()` por `->headers->set()` no middleware. PR aberto em 29/06/2026.
  - **RESOLUCAO:** Elias corrigiu manualmente em producao antes do merge do PR. Headers `x-ratelimit-limit` e `x-ratelimit-remaining` confirmam o middleware corrigido. Covers e mp3s retornam 200. PR #26 permanece como backup documentado.
  - **PR #27 — Ajuste de limites:** Apos o fix do bug, o rate limit de 60 req/min continuava bloqueando batch downloads do desktop. PR #27 adiciona limites diferenciados: 300/min geral, 600/min para arquivos e metadados. Rotas afetadas: `/file/`, `/player`, `/version`, `/version_log`, `/metadata`.
  - **Bug separado — FTP endpoint:** `GET /ftp` retorna 500 com `Firebase\\JWT\\JWT::decode(): Argument #1 ($jwt) must be of type string, null given`. O `FtpController` espera token JWT no parametro `?token=` mas recebe null. Nao e relacionado ao middleware.
- **Pitfall: grep `describe/it/expect` em repos Vue sem test runner:** Esses nomes aparecem como funcoes utilitarias Vuex (currying, iterators) e NAO indicam testes. Sempre verificar o conteudo antes de concluir que testes existem.
- **Params.php:** Logica de versionamento do app Delphi misturada no PHP — acoplamento alto. Mudar requer coord com Mayco (pode quebrar app desktop).
- **config() em testes Lumen e cacheado:** `config(['key' => 'val'])` dentro de testes unitarios NAO sobrescreve o valor em Lumen — o config e cacheado no bootstrap. Workaround: testar via reflection em metodos privados, ou testar o metodo que usa `config()` e aceitar o valor real do ambiente.
- **array_collapse() NAO existe em Lumen:** Laravel Helper `array_collapse()` ausente. Usar `array_merge(...array_values($array))` como substituto.
- **Lumen retorna 500 para rotas inexistentes em testes:** `$this->call('GET', '/rota-inexistente')` retorna 500 (middleware chain quebra) em vez de 404. Testes de error handler devem testar metodos individualmente, nao o HTTP response code de rota inexistente.
- **bootstrap/app.php e modificado por multiplas PRs:** Branches #17, #18, #19, #21 todas adicionam linhas em bootstrap/app.php. Merge em ordem errada pode conflitar. NAO criar mais PRs que mexam em bootstrap/app.php.

---

## Repositórios da Org

| Repo | Stack | Stars | Papel |
|------|-------|-------|------|
| [louvorja/app](https://github.com/louvorja/app) | Vue 3 + Vuetify + Vite | ★27 | Frontend web principal |
| [louvorja/desktop](https://github.com/louvorja/desktop) | Pascal (Delphi/Lazarus) | ★14 | Desktop legado — tela estendida, liturgia, controle remoto server |
| [louvorja/api](https://github.com/louvorja/api) | PHP (Laravel Lumen) | ★3 | API backend |
| [louvorja/site](https://github.com/louvorja/site) | — | ★0 | Site institucional |
| [louvorja/adm](https://github.com/louvorja/adm) | Vue | ★0 | Painel administrativo (sem dev ativo) |

**Repos de terceiros com contribuicoes ativas:**
- `elvieira/LouvorJA` (branch `electron`) — versao Electron do desktop, publico. Elias Vieira. **App Electron funcional** com modules system completo. Ver secao "Electron App (elvieira) — Estado Atual" abaixo.
- `juanaleixo/louvorja` — **FORK MAIS AVANCADO.** 603 commits, 22 modulos funcionais. Stack: Vue 3 + Vuetify 4 + Pinia + TypeScript + Electron. Branches: main (com liturgia mergeada), feat/controle-remoto, feat/sync-projetos. **JA implementa praticamente tudo que o Delphi tem e mais.** Ver tabela de modulos abaixo.

**Modulos do juanaleixo/louvorja (src/modules/):**
| Modulo | Status | Notas |
|--------|--------|-------|
| liturgy | Implementado | Organizador de culto, drag-drop, clone itens |
| bible | Implementado | Busca rapida por versiculo (feat/controle-remoto) |
| favorites | Implementado | Favoritos |
| slide_editor | Implementado | Editor de slides |
| remote_control | Implementado | Controle remoto + SSE (feat/controle-remoto) |
| name_draw | Implementado | Sorteio de nomes/numeros |
| message_board | Implementado | Painel dinamico / recados |
| draw | Implementado | Texto interativo |
| media | Implementado | Video On / media player |
| animation | Implementado | Animacoes (falta ajustar design/botoes) |
| stopwatch | Implementado | Cronometro de culto |
| timer | Implementado | Timer geral |
| clock | Implementado | Relogio |
| counter | Implementado | Counter |
| custom_collections | Implementado | Coletaneas pessoais |
| musics | Implementado | Editor de musicas |
| lyric | Implementado | Player/letras |
| history | Implementado | Historico |
| theme | Implementado | Temas claro/escuro |
| album | Implementado | Album |
| collections | Implementado | Coletaneas |
| hymnal | Implementado | Hinario |

**CONCLUSAO CRITICA:** A analise cruzada electron-vs-delphi (references/electron-vs-delphi-gap-analysis.md) esta **PARCIALMENTE OBSOLETA**. A maioria dos gaps identificados ("FALTA" no Electron) ja foram implementados pelo juanaleixo. O trabalho real agora e integrar, testar e polir — nao reconstruir do zero.

**Visao do Elias (declarada 29/06/2026):** Versao **leve** como core (so musica + projecao) + modulos opcionais. Ja enviou o projeto pro Michael mas sem resposta ainda. Pergunta se deve criar repo novo na org ou continuar no branch atual. **Estrategia de repo: abordagem hibrida** — continuar branch agora, repo na org quando Michael responder.

## PRs de Integração — o PO vs Elias

### PR #37 (o PO)
Módulos adicionados na branch `o PO-pr37`: slide-editor, video, liturgy, bible.
Consulte `references/pr-37-o PO-modules.md` para guia de migração o PO→Elias e padronização de estilo.

**Version:** 1.5.0 | **Stack:** Vue 3 + Vuetify 4 + Vuex 4 + Vite 7 + Electron ^34 + vue-i18n + Options API
**Entry:** `electron/main.js` (frameless window, custom titlebar, menu nativo, custom protocol `local://`)
**Build:** `electron-builder` (AppImage Linux, NSIS Windows, DMG macOS) | `npm run electron:dev` / `npm run electron:build`
**CI/CD:** Apenas `deploy.yaml` (web). Nenhum workflow de build Electron. Issues #1-#12 criadas para priorizar.

**Modulos Core funcionais (src/modules/core/):**
| Modulo | ID | Linhas Vue | Descricao |
|--------|----|-----------|-----------|
| Home | home | 472 | Dashboard com coletaneas recentes e atalhos |
| Musics | musics | - | CRUD de musicas, busca, categorias |
| Collections | collections | 499 | Albuns e coletaneas |
| Hymnal | hymnal | - | Hinario Adventista |
| Hymnal 1996 | hymnal_1996 | - | Hinario Adventista 1996 |
| Bible | bible | - | Leitura biblica com projecao multi-monitor |
| Lyric | lyric | - | Player de letras/projecao |
| Media | media | 448 | Media player (video/audio) |
| Sync | sync | 570 | Biblioteca local / download offline |
| Config | config | 605 | Configuracoes gerais, tema, display |

**Arquitetura IPC (main <-> preload <-> renderer):**
- `electron/main.js`: encrypted local DB (`safeStorage` would be better), media download/cache, display management, window controls, custom `local://` protocol (Range requests, MIME detection, fallback to API URL)
- `electron/preload.js`: exposes `window.electronAPI` (getLocalDb, saveLocalDb, downloadMedia, checkMedia, deleteMedia, clearAllData, windowControl, getDisplays, identifyDisplays)
- Protocolo `local://` serve midia offline com suporte a Range (audio streaming), fallback para `https://api.louvorja.com.br/file` quando arquivo local nao existe

**Electron Desktop — Arquitetura de Dados e Interacao com API (auditoria 30/06/2026):**

A hipotese "Desktop nao bate na API" esta **PARCIALMENTE ERRADA**. O Electron usa uma estrategia de 3 camadas com cache agressivo, mas ainda depende da API em cenarios especificos.

**Camada 1 — Cache em memoria (sessionStorage):**
`Database.js` verifica `db:{file}` no sessionStorage antes de qualquer outra coisa. Mais rapido, mas perdido ao fechar o app.

**Camada 2 — Disco local criptografado (.sysdata/):**
`electronAPI.getLocalDb(file)` le `.bin` criptografados (AES-256-CBC com chave HARDCODED em main.js). Dados persistem entre sessoes. Arquivos salvos via `electronAPI.saveLocalDb()`.

**Camada 3 — API web (fallback):**
`fetch()` para `api.louvorja.com.br/json_db/{file}` com header `Api-Token`. Soh chamada quando o dado NAO existe em nenhuma camada local. Apos baixar, salva automaticamente no disco local (Camada 2) para proximos acessos.

**Fluxo de dados completo por operacao:**

| Operacao | Fluxo | Bate na API? |
|----------|-------|-------------|
| **Primeiro boot** (FirstBootLoader.vue) | Baixa TUDO via `/db/manifest` + 16.871 fetchs individuais (82 albums, 2.509 musicas, 14.268 bible chapters, 6 metadata). Salva tudo no disco local criptografado. | **SIM — massivo** (16.871 fetchs) |
| **Uso diario — dados** (Database.js) | sessionStorage > disco local > API | Raramente (soh se dado novo nao existe localmente) |
| **Covers/imagens** (Path.js) | `local://media/covers/...` (protocolo custom) > fallback API | Raramente (soh se cover nao baixada) |
| **Audio MP3** (Media.js) | `local://media/music/...` (protocolo custom) | **NUNCA no modo strict offline** — bloqueia com erro se arquivo nao existe no disco |
| **Download de coletanea** (sync/Index.vue) | `electronAPI.downloadMedia(url, type, file)` faz `net.fetch(url)` da API e salva no disco | **SIM** (mas por escolha do usuario) |
| **Protocolo local:// fallback** (main.js) | Se arquivo nao existe no disco, faz `net.fetch(api.louvorja.com.br/file{path})` | **SIM** (fallback automatico) |

**Implicacoes para rate limiting (PR #26):**
- **Primeiro boot:** Altamente suscetivel — centenas de requisicoes seguidas podem disparar rate limit
- **Uso diario:** Quase imune — dados servidos do cache local
- **Midia nao baixada:** O fallback do protocolo `local://` chama a API — se a media nao foi baixada via Biblioteca Local, o bug de StreamedResponse afetaria
- **Audio strict offline:** Se o usuario tentou tocar algo que nao baixou, o app BLOQUEIA (nao chega a chamar a API). Portanto o bug de 500 do mp3 NAO afeta usuarios que nao baixaram a midia (eles veem erro diferente: "Essa coletanea ainda nao foi baixada")

**Security issues (confirmados por leitura de codigo):**
- AES-256-CBC key hardcoded em `electron/main.js` linha 7 — qualquer pessoa pode descriptografar DBs locais com a chave publica
- API URL hardcoded como fallback no protocol handler (`https://api.louvorja.com.br/file`) — ignora `VITE_URL_FILES`
- DevTools bloqueado em builds empacotados (`!app.isPackaged`)

**Por que o Desktop eh mais leve:**
- Nao tem backend/banco embutido — Vue.js puro com Electron shell
- Dados sao JSON serializados criptografados no disco (`.bin`)
- O "banco de dados" sao os mesmos JSONs da API, baixados no primeiro boot
- Sem SQLite, sem ORM, sem servidor local
- Tamanho no disco depende do que o usuario baixou na Biblioteca Local (mp3s)

**OneDrive/FTP vs API — Esclarecimento:**
- O link OneDrive compartilhado pelo Elias contem o `.db` SQLite do **Delphi desktop legado** (louvorja/desktop) — eh o metodo antigo de distribuicao de database
- O **Electron NAO usa OneDrive, FTP nem .db** — tudo vem via API REST (`/db/manifest` + `/db/{table}`)
- O helper `Ftp::send_database()` no backend Laravel envia `.db` para FTP como compatibilidade com o Delphi — nada a ver com o Electron
- O endpoint `GET /file/{path}` tenta local primeiro, depois FTP como fallback (FileController::open) — isso serve midias, nao database

**Security issues identificados:**
- AES-256-CBC key hardcoded em `electron/main.js` (line 7) — qualquer pessoa pode descriptografar DBs locais
- API URL hardcoded como fallback no protocol handler (ignora VITE_URL_FILES)
- DevTools bloqueado em builds empacotados (`!app.isPackaged`)

**Issues abertas (30/06/2026) no repo elvieira/LouvorJA — atualizadas apos cleanup:**

Issues existentes mantidas (agregam valor):
- #3 [CI/CD] Sem workflow de build/publish para Electron
- #4 [Feature] Auto-updater para Electron (item 9 da lista do Elias)
- #7 [Improvement] Migrar Options API para Composition API
- #11 [Documentation] README nao reflete o setup Electron

Issues de paridade criadas (BASEADAS na lista confirmada pelo Elias via Telegram):
- #24 [Paridade] Liturgia / organizador de culto (Essencial)
- #25 [Paridade] Biblia completa — multiplos versiculos, busca avancada, personalizacao de texto (Essencial)
- #26 [Paridade] Transmissao ao vivo — output HTML para OBS/Vmix (Essencial)
- #27 [Paridade] Editor de slides (Essencial)
- #28 [Paridade] Sorteio de nomes/numeros (Util)
- #29 [Paridade] Cronometro de culto (Util)
- #30 [Paridade] API local / controle remoto — controle externo de musicas (Util)
- #31 [Paridade] Favoritos (Util)
- #32 [Paridade] Formatacao de texto (Nice-to-have)
- #33 [Paridade] Painel dinamico / recados (Nice-to-have)
- #34 [Paridade] Texto interativo (Nice-to-have)
- #35 [Paridade] Video on (Nice-to-have)

**Issues #1, #2, #5, #6, #8-#12, #13-#23 FECHADAS** (30/06/2026) — nao agregavam valor para paridade com Delphi ou foram inventadas sem dados verificados.

**Lista de paridade confirmada pelo Elias (Telegram 29/06/2026, chat 6572836307):**
Elias confirmou: "Perfeito cara, e praticamente isso mesmo."

Essencial (falta no Electron):
1. Liturgia / organizador de culto (agendamento, ordem de servico)
2. Biblia completa (multiplos versiculos na projecao, busca avancada, personalizacao de texto) — Elias: "Funcional esta, mas nao completo."
3. ~~Tela de retorno / stage display~~ — JA EXISTE no Electron, so esta escondido (Elias: "Eu deixei escondido")
4. Transmissao ao vivo (output HTML pra OBS/Vmix)
5. Editor de slides

Uteis (falta no Electron):
6. Sorteio de nomes/numeros
7. Cronometro de culto
8. API local (controle externo de musicas) — Elias confirmou que existe no Delphi, incluindo controle de liturgia
9. Auto-update do app
10. Favoritos

Nice-to-have (falta no Electron):
11. Formatacao de texto
12. Painel dinamico / recados
13. Texto interativo
14. Video on

**PITFALL CRITICO — NAO fabricar issues sem dados verificados:**
Na sessao 30/06, issues #13-#23 foram criadas com afirmacoes falsas ("lyric -25 linhas, home +323 linhas") que nunca foram verificadas por leitura real de arquivos. O GitHub API retornava output de 1 linha e o assistant INVENTOU dados pra preencher a tabela. Resultado: 11 issues tiveram que ser apagadas. REGRA: nunca criar issues de paridade comparando branches sem primeiro ler os arquivos REALMENTE via gh api ou clone local. Se nao conseguir ler, NAO invente — pergunte ao usuario ou use a fonte de verdade (Telegram com o Elias).

**Specs com criterios de aceite criadas (29/06/2026):** Arquivo `/tmp/LOUVORJA_SPECS.md` — 22 specs em 5 fases com criterios de aceite detalhados (checkboxes), arquivos afetados, passos de teste, e referencia ao codigo existente. Ver `references/elias-electron-specs.md` para resumo. O Elias autorizou organizacao de issues. **NUNCA misturar trabalho do juanaleixo com do Elias** — sao projetos distinctos.

**Style Guide do Electron mapeada (30/06/2026):** Toda a style guide do branch `electron` foi auditada e documentada em `references/electron-style-guide.md`. Contém: 22 CSS custom properties (light + dark), tipografia, layout (titlebar 32px, sidebar 350px, content calc(100vh-70px)), scrollbar customizada, 9 componentes com scoped styles mapeados, padrões de cards/table/search/alert, animações (fade, slide-up, pulse), breakpoints (1024px/768px), e 12 regras invioláveis. **Referência obrigatória ao implementar qualquer feature de paridade (#24-#35).**

**Elias NAO usa TDD:** Investigado em 29/06/2026. Zero test files, zero test runners, zero CI de testes no repo `elvieira/LouvorJA`. Os `describe/it/expect` encontrados pelo grep sao funcoes Vuex utilitarias (currying, state access), NAO testes. Aplicar Project Excellence COMPLETO seria overkill — usar "Direto" (Light Mode) como default para issues do Elias. Adicionar RF-IDs nas specs e classificar issues, mas manter testes manuais. NAO exigir TDD dele.

**Specs vs Project Excellence:** As specs criadas em `/tmp/LOUVORJA_SPECS.md` NAO foram avaliadas contra Project Excellence/SDD. Gaps: sem RF-IDs, sem testes automatizados, sem Classification Gates, sem QA Agent gates. Decisao pragmatica: nao forcar compliance total num projeto de dev solo sem infra de testes.

**Elias Telegram:** user_id `6572836307`, username `elvieira9`. **NUNCA perguntar ao Elias sobre organizar issues** — ja autorizado. Usar `/usr/bin/python3` para scripts Telethon (venv do Whisper nao tem Telethon). **Lista de paridade confirmada esta nesse chat (msg 29/06/2026)** — sempre ler de la em vez de tentar recriar por diff de codigo.

**Forks do o PO:**
- API: https://github.com/Piano-Louvor-JA/api (local: /home/ubuntu/dev/workspace/projects/api)
- App: https://github.com/Piano-Louvor-JA/app

**PR #49 (juanaleixo) — CRÍTICO:** 406 arquivos, +50k/-13k linhas. Port Electron, Vuex→Pinia, TS, Vuetify 4, liturgia, SSE para controle remoto. Sem reviews há 38+ dias. Se mergear, issues #42/#45/#47 e PRs #56/#57/#58 ficam obsoletos. **Este PR e o caminho mais rapido para ter o Electron funcional.**

**Canais Telegram:** @louvorja (canal oficial, feedbacks de usuários), grupo de devs: -1002108908408

### Iniciativas em Andamento (2026-06-27)

| Iniciativa | Quem | Status | Notas |
|------------|------|--------|-------|
| **LouvorJ.AI Chatbot** | Thayza Raquel (@Thayza_Raquel) | Em andamento | Groq API + RAG, guardrails topico, so responde sobre LouvorJA. Prioridade: Web primeiro, Desktop depois. Vai integrar nos repos existentes (nao repo novo). Nome: "Louvor J.AI". Thayza criou logo (circulo azul-amarelo, 4 petalas). Logo em `/home/ubuntu/telegram-client/thayza_logo.jpg`. Grupo de devs: -1002108908408. |
| **Electron Desktop** | Elias Vieira (@elvieira9) | ~85% | Versao Electron do desktop Delphi. Repo: `github.com/elvieira/LouvorJA/tree/electron`. Hinarios 2022/1996 + coletanea + biblia + projecao monitor estendido funcionais. Roda nativo Mac/Windows/Linux. Builds disponiveis (AppImage Linux). Precisa: search biblia, multi-versos, configuracoes. |
| **HTML/JS Desktop** | Diego Menezes (@Ajegado) | Em andamento | Versao web embutida no desktop |
| **Figma + Logos** | Elomar (@Elomark) | Em andamento | Telas em Figma + logos Igreja/Aventureiros/DVB em SVG. Fazendo logos sob demanda (ex: icones p/ Diego 29/06). |
| **Electron QA Linux** | Ezequias Fonseca | Testando | Testou build Electron no Linux, publica AppImage pro grupo |

### Design Tokens — App Web (louvorja/app)

**Stack:** Vue 3 + Vuetify 3 + Vuex 4 + Vite + Sass + vue-i18n + ModuleManager

**Temas Vuetify (src/plugins/vuetify.js):**
| Theme | Dark | Primary |
|-------|------|---------|
| darkblue (DEFAULT) | No | #1b2a41 |
| light | No | #29569b |
| blue | No | #0b3d62 |
| green | No | #077568 |
| orange | No | #d24726 |
| purple | No | #80397b |
| pink | No | #e91e63 |
| black | No | #2e2e2e |
| dark | Yes | #2e2e2e |

**Fonte custom:** DINCondensedBold (src/assets/fonts/din-condensed-bold.ttf)
**Icones:** @mdi/font (Material Design Icons)
**Layout:** AppsRibbon, TrayArea, SystemBar, Menu lateral, Header, Footer, Alert, Loading
**Arquitetura modular:** ModuleManager + manifest.json por modulo em src/modules/core/
**State:** is_dark, is_mobile, is_desktop, is_online, user_data.theme, user_data.language
**Scrollbar:** Customizada (light: #f3f3f3/#dedede, dark: #1a1919/#111010)

### Design Tokens — Desktop (louvorja/desktop — Delphi)

**Skin engine:** AlphaControls (bsSkinExCtrls), centralizado em dmComponentes (bsSkinData1)
**Fonte default:** Tahoma 13pt (DefaultFont, DefaultEditFont, DefaultLabelFont, etc.)
**Cores customizaveis por usuario:** corLetra, corLetra_aux, corFundo, corTextoMusica, corTextoRepetido, corTituloMusica, corFundoMusica
**Componentes skin:** bsSkinButton, bsSkinSpeedButton, bsSkinDBText, bsSkinColorButton, bsSkinPopupMenu
**Skin elements:** button, panel, edit, combobox, stdlabel, toolmenubutton, buttonedit, spinedit, checkbox, officegroupdivider, header
**Core sistema:** clWhite, clBlack, clWindowText
**Icones:** TbsPngImageList (PNG compilados em .res). Tamanhos: ico_16x16, ico_24x24, ico_40x40, ico_64x64, ico_flags. Arquivos .ico em `Arquivos Projeto/ico/`.
**Forms:** 1 form principal (fmMenu ~1.9MB DFM) + 20+ forms auxiliares

**Delphi BGR→Hex (cores extraídas do fmMenu.dfm):**

| Hex | BGR int | Uso provável |
|-----|---------|-------------|
| `#08192D` | 2955528 | Background primário escuro |
| `#1E467B` | 8078878 | Azul médio |
| `#29569B` | 10180137 | Botões/ações (accent) |
| `#A5B9D2` | 13810085 | Texto secundário claro |
| `#0B3D62` | 6438155 | Azul escuro (send buttons) |
| `#00004F` | 5177344 | Navy profundo |
| `#1A1A1A` | 1710618 | Background escuro |
| `#232323` | 2302755 | Painel |
| `#2C2C2C` | 2894892 | Surface/input |
| `#353535` | 3487029 | Elevated surface |
| `#525252` | 5395026 | Border |
| `#FF8000` | 33023 | Orange accent |
| `#004000` | 16384 | Green (success) |

**Conversão BGR→Hex (Python):**
```python
b, g, r = (i >> 16) & 0xFF, (i >> 8) & 0xFF, i & 0xFF
hex_color = f'#{r:02X}{g:02X}{b:02X}'
```

### louvorja-site (Site Institucional) — Stack SEPARADA

**CRITICAL:** O site (`louvorja/site`) é um projeto INDEPENDENTE do app web. NÃO usa Vuetify — usa Bootstrap 5 + jQuery + vue-i18n + vue-router + vue3-carousel. Componentes Vue devem usar CSS scoped puro, não Vuetify classes (`<v-btn>`, `<v-app-bar>`, etc.). Ao criar views para o site, escrever todo o CSS inline/scoped sem depender de framework UI.

| Dep | Versão | Nota |
|-----|--------|------|
| Bootstrap | ^5.3.3 | Framework CSS (NAO Vuetify) |
| jQuery | ^3.7.1 | Bootstrap dependency |
| Vue 3 | ^3.5.13 | Options API ou Composition |
| vue-i18n | ^11.0.0-rc.1 | PT/ES |
| vue-router | ^4.5.0 | Lazy-loaded routes |
| Vite | ^6.2.0 | Dev server |

**Rota pattern** — lazy-loaded: `{ path: '/chatbot', name: 'chatbot', component: () => import('../views/Chatbot.vue') }`
**Header nav pattern** — desktop `<li><router-link :to="{ name: 'chatbot' }">Label</router-link></li>`

### Fontes e Ícones — Sources

| Plataforma | Recurso | Source |
|---|---|---|
| Desktop | Tahoma 13pt | Windows system (builtin) |
| Web | DINCondensedBold | `src/assets/fonts/din-condensed-bold.ttf` (custom, @font-face) |
| Web | Roboto | Google Fonts CDN (`webfontloader.js`: `Roboto:100,300,400,500,700,900`) |
| Web (animation) | Barlow + Barlow Condensed | Google Fonts CDN |
| Web | Material Design Icons | `@mdi/font@7.4.47` CDN (`<v-icon icon="mdi-xxx">`) |
| Web | Logo custom | `src/assets/imgs/logo.svg` (registrado como `$louvorja`) |
| Site | Roboto (CDN) | Google Fonts via `<link>` no index.html |
| Desktop | PNG icons | `TbsPngImageList` compilados em `.res` (5 tamanhos) |
| Desktop | App icons | `.ico` em `Arquivos Projeto/ico/` (`louvorja_slja.ico`, `louvorja_lja.ico`, `Logo.ico`) |

Veja `~/ObsidianVault/04-Projects/LouvorJA-Org-Mapa-e-Oportunidades.md` para mapeamento completo de todos os repos, PRs, issues e oportunidades.

---

## Contribuição para louvorja/api (Backend)

### Workflow de Fork + PR

```
Clone local: /home/ubuntu/dev/workspace/projects/api
Fork:        github.com/Piano-Louvor-JA/api
Upstream:    github.com/louvorja/api
Mantenedor:  Mayco (approva PRs diretamente)
```

**Regra de ouro:** PRs devem ser PEQUENOS e SEQUENCIAIS. Mayco revisa sozinho — PR de 30 linhas entra, PR de 300 linhas fica parado.

### Passos para contribuir

1. `cd /home/ubuntu/dev/workspace/projects/api`
2. **SINCRONIZAR FORK ANTES DE TUDO** (CRITICAL — se pular, branch fica desatualizada e rebase falha):
   ```bash
   git fetch origin main
   git checkout main
   git pull origin main              # fast-forward com os merges do Mayco
   git push fork main                # sincroniza o fork (remente 'fork', nao 'origin')
   ```
   **Pitfall:** O branch local pode ficar MUITO atrasado (ex: 45 commits). Sempre fazer `git pull origin main` (NAO apenas `git fetch`). Se `git stash` for necessario, faca antes do pull.
3. **LIMPAR arquivos não rastreados** de branches anteriores (ex: arquivos de PRs abertos que ainda não foram merged). Se não limpar, `git checkout -b` pode falhar com "untracked working tree files would be overwritten":
   ```bash
   git clean -fd app/ tests/ public/   # remove arquivos órfãos de branches anteriores
   ```
4. `git checkout -b feat/descricao-curta main`
5. Implementar mudança mínima (idealmente 1-2 arquivos)
6. Rodar testes: `vendor/bin/phpunit` (ou `php artisan test` se disponível)
7. **PUSH para o FORK** (origin = louvorja/api sem permissao de push):
   ```bash
   git push fork feat/descricao-curta    # NAO git push origin — vai dar Permission denied
   ```
8. **PR via gh cli com HEAD apontando pro fork**:
   ```bash
   gh pr create --repo louvorja/api --base main --head Piano-Louvor-JA:feat/descricao-curta
   ```
   **Pitfall:** Sem `--head Piano-Louvor-JA:branch`, o GitHub nao encontra a branch (esta no fork, nao no repo principal).

**Assinatura de commits:** Carregar skill `git-commit-signing` antes do primeiro commit. Chave `47FECA848C9FB0F0` (sem passphrase) funciona em CI/sem-TTY. Chave `3482358A57244D32` (com passphrase) falha com exit 128 sem TTY. Comando: `git -c user.signingkey=47FECA848C9FB0F0 commit -S`.

**Dica — bulk find-replace em PHP:** Para refactors que tocam muitos arquivos (ex: env()→config()), use `execute_code` com Python `str.replace()` em loop sobre os arquivos. Muito mais confiável que `sed` para strings PHP com aspas misturadas (env("FOO") vs env('FOO')). Após替换, rode um scan de verificação procurando por `env(` restantes em arquivos que não sejam de config.

### Preferencia: Contexto define abordagem

Duas abordagens validas dependendo do pedido do usuario:

1. **Quick fix (incendio):** Quando usuario relata um problema especifico (ex: "Diego nao sabe quais JSONs existem"), faca o menor PR possivel que resolve a dor. Nao comece com SPEC/PLAN.

2. **SDD completo (elevar nivel):** Quando usuario pede explicitamente "elevar o nivel", "SDD", "project excellence", ou "todas as frentes", faca o raio-X completo e entregue os 4 artefatos SDD (SPEC, PLAN, AGENTS, CONTEXT) antes de implementar. Cada fase do PLAN vira um PR separado.

O usuario e sonoplasta na igreja e usa o sistema LouvorJA. Tem interesse pessoal em melhorias. PRs devem ser sempre pequenos e sequenciais independente da abordagem.

### SDD Planning Artifacts (2026-07-01)

Em 01/07/2026, um novo ciclo SDD completo foi gerado em resposta aos pedidos do Diego (Ajegado). Os artefatos estao em `/home/ubuntu/dev/workspace/projects/louvorja-api/.planning/`:

- **SPEC.md** — Baseline completa (31 públicos + 27 admin + 8 tasks, 21 tabelas, 22 controllers, 11 middlewares), 9 RFs documentados (incluindo RF-007 a RF-009: Doxologia/Kids sem type, Hymnal sem show, show() sem rota publica), 9 FRs (FR-001 a FR-009 cobrindo exatamente os 4 endpoints que o Diego pediu), 10 NFs, analise de impacto com mitigacoes, rastreabilidade completa.
- **PLAN.md** — 5 fases, 16 tasks. Cada task = 1 PR pequeno (< 50 linhas). F1: correcoes de dados/bugs (3 tasks, 1 dia). F2: endpoints do Diego (4 tasks, 2 dias). F3: manifest/download da DB (3 tasks, 1 dia). F4: merge PRs abertos #6/#27 (3 tasks, 0.5 dia). F5: testes/documentacao (3 tasks, 0.5 dia).
- **AGENTS.md** — Guia para devs: stack, estrutura, regras de PR (fork workflow), pitfalls PHP/Lumen/Git/Telegram, comandos, contatos.
- **CONTEXT.md** — Handoff resumido.

**Pitfall critical:** `config(['key'=>'val'])` em testes Lumen NAO sobrescreve — o config e cacheado no bootstrap. Workaround: test via reflection ou aceite o valor real do ambiente.

### Backlog de melhorias — SDD Plan (auditado 2026-06-21)

**Artefatos SDD completos** em `/home/ubuntu/dev/workspace/projects/api/.planning/`:
- `SPEC.md` — 8 RFs (OpenAPI, rate limiting, testes, SQL injection, CORS, export, caching, health)
- `PLAN.md` — 11 tasks em 6 fases
- `AGENTS.md` — Guia para agentes de IA
- `CONTEXT.md` — Handoff completo

| PR | Branch | Foco | Status (21/06) |
|----|--------|------|--------|
| #3 | feat/json-db-manifest | GET /json_db manifest (name + size) | **MERGED** |
| #4 | feat/test-foundation | PHPUnit 10 + SQLite in-memory + 3 suites | **MERGED** |
| #5 | fix/sql-injection-file-controller | SQL injection fix FileController | **MERGED** |
| #6 | feat/security-headers-cors | CORS whitelist + security headers | **MERGED** |
| #7 | feat/openapi-documentation | swagger-php + Swagger UI | **CLOSED (conflito)** → substituida por #11 |
| #8 | feat/export-categories-caching | Export JSON com cache + paginacao | **CLOSED (conflito)** → substituida por #12 |
| #9 | feat/rate-limiting-health-check | Rate limiting por IP + /health | **CLOSED (conflito)** → substituida por #13 |
| #10 | fix/env-to-config-cache-safe | env()→config() — 36 replaces, config:cache compat | **MERGED** |
| #11 | feat/openapi-documentation | swagger-php + Swagger UI (rebased) | **Aberto** |
| #12 | feat/export-categories-caching | Export JSON com cache + paginacao (rebased) | **Aberto** |
| #13 | feat/rate-limiting-health-check | Rate limiting por IP + /health (rebased) | **Aberto** |
| #14 | fix/ssl-verify-services | SSL verify default true + unificar YoutubeService com config | **Aberto** |
| #15 | fix/remove-dead-code-data-helper | Remove dead code do Data helper | **Aberto** |
| #16 | feat/version-endpoint | GET /version — versao API, PHP, Lumen, min_client_version | **Aberto** |
| #17 | refactor/jwt-hardening+revoked-blacklist | JWT refresh token rotation + blacklist graceful handling | **Aberto** |
| #18 | fix/json-error-handler | Error handler JSON padronizado (PT-BR, debug-safe) | **Aberto** |
| #19 | feat/structured-logging | Monolog channels + RequestLoggingMiddleware (log level adaptativo) | **Aberto** |
| #20 | feat/api-key-management | Multiplas API keys com labels + hash_equals timing-safe | **Aberto** |
| #21 | feat/env-validation | EnvValidator::check() fail-fast no bootstrap | **Aberto** |
| #25 | feat/swagger-docs-all-endpoints | OpenAPI 3.0 docs — 22 controllers, 59+ endpoints, Swagger UI, dynamic server URL, prod dropdown, all endpoints smoke-tested vs prod | **Aberto** |
| #26 | fix/rate-limit-streamed-response | Fix StreamedResponse 500: `->header()` → `->headers->set()` em RateLimitMiddleware | **Aberto (backup — Elias corrigiu manualmente em prod)** |
| #27 | fix/adjust-rate-limiting-for-desktop-app | Limites diferenciados por tipo de rota: 300 geral, 600 arquivos/metadados (antes 60 fixo). Novas .env vars: RATE_LIMIT_FILE_MAX, RATE_LIMIT_METADATA_MAX | **Aberto** |

**MERGED:** #3, #4, #5, #6, #10, #13, #19, #22, #25 (9 em producao).
**OPEN aguardando Mayco:** #11, #12, #14, #15, #16, #17, #18, #20, #21.

PRs #7-#9 foram fechadas por conflito apos merges do Mayco no main. Reabertas como #11-#13 rebased no main atualizado, sem conflito. PRs #13 (rate limiting), #19 (structured logging), e #25 (Swagger docs) foram merged apos rebases.

**Nota sobre PRs merged com contrib do o PO:** #9→#13 (rate limiting), #19 (Monolog logging), #25 (Swagger docs completos). Commits do o PO confirmados no main via `git log --author="o PO"` — todos estao no branch main.

Ordem de merge recomendada: qualquer ordem — todos estao CLEAN/MERGEABLE.

**Ultima sincronizacao de conflitos:** 2026-06-23. PRs #12, #13, #19 rebased contra upstream/main e force-pushed. Todos os commits assinados com SSH (chave vm: SHA256:RFRgUqNpV2e4/7XKKHZ3iM1gO+6YtSJIyQp8G/EaAhg). Comentarios deixados nos 3 PRs indicando resolucao.

**Padrao para resolver conflitos em fork (louvorja/api):**
1. `git fetch upstream && git fetch origin`
2. `git checkout feat/branch-name`
3. `git rebase upstream/main` (NAO origin/main — upstream e o repo oficial)
4. Resolver conflitos mantendo features do PR + novidades do HEAD
5. `git add <files> && GIT_EDITOR=true git rebase --continue`
6. Verificar: `git log --pretty=format:"%h %G? %s" upstream/main..HEAD` (todos G)
7. Push: `git push --force origin feat/branch-name`
8. Comentar no PR: `gh pr comment <N> --repo louvorja/api --body "✅ Merge conflicts resolvidos"`

**Backlog técnico completo** (prioridades P1-P3, API + App): `~/ObsidianVault/04-Projects/LouvorJA-Proximas-Contribuicoes.md`
**Discord tracking thread:** #geral → "🎸 Louvor JA — Contribuições Open Source"

**NOTA:** Cada fase usa branch limpo do main (fetch upstream, merge, push origin, clean untracked, criar branch). Isso garante diff limpo para PR. Infraestrutura compartilhada (TestCase namespace, phpunit.xml, composer.json autoload-dev) deve ser incluida em cada branch que precisa de testes.

**GPG signing:** Chave `47FECA848C9FB0F0` (sem passphrase) funciona em CI/sem-TTY. Chave `3482358A57244D32` (com passphrase) falha com exit 128 sem TTY. Sempre usar: `git -c user.signingkey=47FECA848C9FB0F0 commit -S`.

### Requests NÃO Implementados (Pendentes)

Quando Mayco solicita features via Telegram/grupo, verifique abaixo antes de assumir que já está feito:

**Categorias (ATUALIZADO 2026-06-23):**
- **CategoryController EXISTE** com CRUD completo (index/show/store/update/destroy) + CategoryAlbumController para associações
- PR #12 ainda relevante para endpoint genérico de colunas únicas
- O que existe:
  - CRUD dedicado: `GET/POST/PUT/DELETE /categories` (CategoryController)
  - Associações: `GET/POST/PUT/DELETE /categories/{id}/albums` (CategoryAlbumController)
  - Arquivo estático: `GET /json_db/pt_categories` (preexisting, sem cache)
  - PR #12: `GET /db/{table}/categories?column=X` — retorna valores únicos de uma coluna qualquer

**Como verificar se algo foi implementado:**
1. Checar tabela de PRs acima
2. Se não aparece, não foi feito
3. Verificar no repo louvorja/api aberto (web ou local) se controller existe
4. Telegram session expira rápido (2FA ativa?) — evitar depender de busca histórica no grupo

**Fluxo correto quando Mayco solicita algo:**
1. Registrar solicitação em `~/ObsidianVault/04-Projects/LouvorJA-Proximas-Contribuicoes.md`
2. Implementar e abrir PR
3. Atualizar tabela de PRs nesta skill
4. Depois verificar no Telegram se ele mergou (usar web.telegram.org ou sessão ativa)

### Helpers (logica de dominio, metodos estaticos)

| Helper | O que faz |
|--------|-----------|
| `Data` | Query builder: sort_by, filtros (like, or, gt, lt), paginacao. **Usado por todos os controllers index().** CRITICO |
| `Configs` | CRUD de configs (key/value/type) + versionamento + refresh diario |
| `DataBase` | `export_json()` — gera JSONs individuais por tabela em `public/db/json/` |
| `GenerateStaticJsons` | Gera JSONs estáticos aninhados por idioma (categorias+albums, hinario, collections) com `_meta.hash` para ETag. `generate()` e `getHash()` |
| `Files` | refresh_size, refresh_duration (getID3), list_files, zip de diretorios |
| `Ftp` | `send_database()` — envia DB SQLite via FTP para servidores das igrejas |
| `Tables` | Lista tabelas: all(), system(), public() (exclui system tables do export) |
| `Params` | Parametros do app Delphi (versao, download URL, setup name) |
| `OnlineVideos` | Sync YouTube channels/playlists/videos com YouTube Data API v3 |
| `Validations` | Mensagens de validacao PT-BR |

## Legado Delphi

Para porting do sync legado (louvorja/desktop) para o Electron, ver `references/legacy-delphi-sync-architecture.md` — inclui arquitetura fmAtualiza.pas, fmNovaVersao.pas, fmMenu.pas, gap analysis, e workaround para arquivos UTF-16.

### Services (integracoes externas)

| Service | O que faz |
|---------|-----------|
| `TelegramService` | Bot sendMessage (Http facade, verify=config('files.ssl_verify')) |
| `YoutubeService` | YouTube Data API v3: channel, playlist, playlistItems (Guzzle, verify=config('files.ssl_verify') — unificado no PR #14) |

### Models (Eloquent)

Todos extendem `BaseModel` que faz logging automatico de mudancas. Chave primaria nao-convencional (id_music, id_album, id_file, etc).

| Model | PK | Relacionamentos |
|-------|-----|-----------------|
| `Music` | id_music | belongsToMany Album (via albums_musics) |
| `Album` | id_album | belongsToMany Category + Music |
| `Category` | id_category | belongsToMany Album (pivot: name, order) |
| `File` | id_file | Accessor: url (FILES_URL + dir + file_name) |
| `User` | id | JWTSubject, permissions (array cast), is_admin, is_temporary_password |
| `Config` | — | key/value/type (json, number, string) |

Veja `references/api-route-map.md` para detalhes do `DataBase::export_json()` e gaps conhecidos.
Veja `references/api-codebase-audit.md` para o raio-X completo (vulnerabilidades, code smells, arquitetura).
Veja `references/phpunit-lumen-setup.md` para o padrao de PHPUnit com SQLite in-memory (template reusavel).
Veja `references/louvorja-org-mapping.md` para mapeamento completo da org (repos, issues, oportunidades de contribuicao, PR #49 status).
Veja `references/electron-gap-analysis-obsolete.md` para status atualizado do gap analysis (juanaleixo com 22 modulos torna a maioria dos gaps obsoletos).
Veja `references/remote-control-architecture.md` para mapeamento completo do sistema de controle remoto (9 endpoints do desktop Pascal, integração web app, gap de endpoints nao utilizados, problemas de UX identificados).
Veja `references/static-json-generation-pattern.md` para o padrao GenerateStaticJsons (JSONs estaticos com hash/ETag, task route, PR #28).
Veja `references/elias-electron-specs.md` para as specs com criterios de aceite do projeto Electron do Elias (22 specs, 5 fases, 29/06/2026).
Veja `references/elias-electron-architecture.md` para a auditoria completa do branch electron (IPC handlers, protocolo local://, modules, security, issues #1-#12, 30/06/2026).
Veja `references/electron-data-architecture.md` para a arquitetura de dados do Electron: fluxo de cache em 3 camadas, protocolo local://, FirstBootLoader, Biblioteca Local, e impacto do PR #26 por cenario de uso.
Veja `references/electron-main-parity-analysis.md` para diff detalhado de modulos, helpers, layout, store entre branches main e electron. **NOTA: dados desse arquivo sao UNRELIABLE — diff foi feito com output truncado do GitHub API. Use a lista de paridade do Telegram (chat 6572836307, 29/06/2026) como fonte de verdade.**

### Pitfall — Criar issues SEM dados verificados (FABRICACAO DE DADOS)
**LESSAO DA SESSAO 30/06/2026:** Issues #13-#23 foram criadas com DADOS FABRICADOS. O GitHub API retornava output truncado (1 linha) e o assistant INVENTOU afirmacoes como "lyric -25 linhas, home +323 linhas" sem nunca ter lido os arquivos. Resultado: 11 issues apagadas.

**Regras OBRIGATORIAS para criar issues de paridade:**
1. **Fonte de verdade eh o Telegram com o Elias** (chat 6572836307). A lista confirmada por ele em 29/06/2026 e a referencia autoritativa.
2. Se for comparar branches via codigo, LEIA os arquivos realmente (gh api com jq, ou clone local). Se o gh api retornar output vazio/truncado, NAO invente — reporte o problema e espere.
3. NAO crie issues de "paridade de helpers/store/plugins/CSS" genéricas baseadas em suposicao. Sem diff real, sao ruido.
4. Issues de melhoria/segurança/CI que o Elias NAO pediu devem ser evitadas — ele nao pediu security audit nem LICENSE. Foque no que ele pediu: paridade com Delphi.
5. Se a lista de paridade ja existe no Telegram, use ELA diretamente. Nao tente recriar por diff de codigo.
Veja `references/electron-style-guide.md` para a style guide completa do branch `electron` do elvieira/LouvorJA (mapeada em 30/06/2026): variáveis CSS, sistema de cores light/dark, tipografia, layout, scrollbar, animações, responsividade, padrões de componentes, e 12 regras invioláveis. **FONTE DE VERDADE para qualquer implementação de features no Electron do Elias.**

Veja `references/subagent-delegation-pitfalls.md` para pitfalls ao delegar criação de módulos LouvorJA para subagentes via `delegate_task` — subagentes falham silenciosamente ao escrever arquivos em `core/`, pulam arquivos grandes (Index.vue), ou criam diretórios vazios. **Prefira write_file in-parent para módulos LouvorJA, especialmente para arquivos Vue com 300+ linhas.**
Veja `references/canonical-design-tokens.md` para design tokens canonicos extraidos dos 5 repos oficiais (cores, fontes, icones, border radius, logo). FONTE DE VERDADE para qualquer design novo.
Veja `references/categories-implementation-status.md` para status atual de categorias (PR #12 vs CRUD completo, implementacao padrao, como verificar se Mayco requisitou algo especifico).
Veja `references/swagger-openapi-pattern.md` para padrao de anotacoes OpenAPI (PHP 8 Attributes, tags, security scheme, bulk annotation workflow) **e pitfalls criticos** (OA\\Object nao existe, PHP built-in server bypassa .json, pre-generation pattern, GeneralMiddleware IP access).
Veja `references/api-disaster-recovery.md` para padroes de disaster recovery (mirror na VM, deteccao rapida de bugs de middleware, abordagens OneDrive).
Veja `references/electron-vs-delphi-gap-analysis.md` para gap analysis entre Electron (elvieira/LouvorJA) e Delphi (louvorja/desktop) — feature matrix completa, modulos faltantes, e workflow para reproduzir a analise.
Veja `references/dev-seed-strategy.md` para strategy de seed local (baixar 16.871 JSONs via /db/manifest para dev offline sem bater na API de producao).
Veja `references/louvorja-api-2026-07-01-sdd-planning.md` para FR-001 a FR-009 (novos endpoints pedidos pelo Diego), bugs ativos (RF-007 a RF-009), cross-validation com Telegram, e estruturas de banco/rotas completas. Este arquivo documenta o SDD de 01/07/2026 e os artefatos em `.planning/SPEC.md`, `.planning/PLAN.md`, `.planning/AGENTS.md`, `.planning/CONTEXT.md`.

---

## Documentação Adicional

No repositório:
- `docs/setup.md` — Este documento (expandido)
- `CLAUDE.md` — Convenções, stack, estrutura
- `CONTRIBUTING.md` — Ambiente, comandos, criação de módulos, fluxo de PR
- `ARCHITECTURE.md` — Camadas, composables vs helpers, BroadcastChannel
- `docs/design-system.md` — Tokens CSS, paleta, tipografia

---

## Workflow de Comunicação Telegram-GitHub-API

Padrão recorrente quando Diego ou outros membros pedem features via Telegram:

1. **Verificar mensagens marcadas no grupo de devs:**
   - Chat ID: `-1002108908408` (grupo "Louvor JA - Dev")
   - Script padrão em `/home/ubuntu/telegram-client/`
   - Buscar por menções ao usuário ou contexto específico

2. **Investigar o pedido:**
   - Clonar repositório relevante (louvorja/api, louvorja/desktop)
   - Verificar código atual e PRs abertos
   - Identificar se a feature já existe ou precisa ser implementada

3. **Implementar se necessário:**
   - Criar branch no fork (Piano-Louvor-JA/api)
   - Fazer mudanças mínimas seguindo regra de ouro (PRs pequenos)
   - Testar localmente

4. **Responder no Telegram:**
   - **CRITICAL:** Só enviar mensagem no grupo de devs quando o usuário pedir EXPLICITAMENTE
   - Nunca mandar por conta própria após completar tarefas ou aberturas de PR
   - O usuário avalia quando é o momento certo de comunicar

## Rate Limiting

Ver `references/rate-limiting-architecture.md` — arquitetura de buckets separados (files/metadata/general), lang prefix normalization, PR #27, pitfalls do contador compartilhado original.

5. **Se não tiver permissão de push:**
   - O o PO não tem permissão de admin na org louvorja
   - Não pode dar permissão a outros membros (ex: Diego)
   - Não pode dar push direto no repo louvorja/api
   - Solução: Usuário deve fazer push manualmente ou dar permissão

**Exemplo de workflow:**
```python
# Script para buscar menções recentes
# /home/ubuntu/telegram-client/check_mentions.py
# Busca mensagens dos últimos 7 dias, filtro por usuário
```

### Pattern — Identificar demandas no grupo de devs

Quando o usuario pede "identifique a demanda" ou "veja o que pedem no grupo", use este pattern:

**Sessao Telethon que funciona (confirmada 30/06/2026):**
- Session: `/home/ubuntu/telegram-client/louvor_ja_session.session` (110KB, autenticada)
- API_ID: `24912664`
- API_HASH: `e6ee7a8bf3af9d66fa7a76b44ad9bc35`
- Python: `/usr/bin/python3` (NAO usar venv do Whisper)

**Para ler chat privado (ex: Elias, chat_id 6572836307):**
```python
import asyncio
from telethon.sync import TelegramClient

client = TelegramClient('/home/ubuntu/telegram-client/louvor_ja_session', 24912664, 'e6ee7a8bf3af9d66fa7a76b44ad9bc35')
client.connect()
entity = client.get_entity(6572836307)
for msg in client.iter_messages(entity, limit=50):
    print(f'[{msg.date}] {msg.text[:200] if msg.text else "[media]"}')
client.disconnect()
```

**Pitfall:** Chats privados (user_id positivo) usam `PeerUser`, NAO `PeerChannel`. Timeout de 600s em tentativas anteriores — se travar, mate o processo e use `telethon.sync` (NAO `asyncio.run`) com script inline via `python3 << 'PYEOF'`.

**Pitfall:** Links `web.telegram.org/a/#6056091989` NAO sao acessiveis diretamente pelo Hermes. Use Telethon com o entity ID (numero apos `#-`). Chat privado pode estar vazio — sempre comece pelo grupo.

### Pattern — Filtrar mensagens de usuario especifico no grupo

```python
async for message in client.iter_messages(group, limit=200):
    if message.sender:
        name = f"{message.sender.first_name or ''} {message.sender.last_name or ''}".strip()
        if 'Thayza' in name or message.sender.username == 'Thayza_Raquel':
            print(f'[{message.date}] {name}: {message.text[:400]}')
```

### Pattern — Filtrar mensagens por keywords

```python
KEYWORDS = ['chatbot', 'bot', 'intelig', 'chat', 'assistente', 'feature', 'funcional']
async for message in client.iter_messages(group, limit=300):
    if message.text and any(kw in message.text.lower() for kw in KEYWORDS):
        sender = message.sender.first_name if message.sender else '?'
        print(f'[{message.date}] {sender}: {message.text[:300]}')
```

**Pitfalls:**
- Telegram session expira rápido (2FA ativa?) — evitar depender de busca histórica
- Quando Mayco solicita algo via Telegram, pode não estar implementado ainda
- Verificar tabela de PRs nesta skill antes de assumir que algo existe
- **NUNCA enviar mensagens automáticas no Telegram — aguarda comando explícito**
- **CRITICAL:** Não mandar mensagem no grupo de devs (-1002108908408) quando o usuário pedir EXPLICITAMENTE
- Nunca mandar por conta própria após completar tarefas ou aberturas de PR
---

## Endpoint /onlinevideos — Suporte a JSON

**Controller:** `OnlineVideosController::index()`
**Rota:** `GET /onlinevideos`

### Formatos suportados

1. **SQL (default — compatível com Delphi Desktop):**
   ```
   GET /onlinevideos
   ```
   Retorna: `DELETE FROM ONL_CANAIS|INSERT INTO ONL_CANAIS (...)|INSERT INTO ONL_PLAYLISTS (...)|...`

2. **JSON (novo — para Electron/VueJS):**
   ```
   GET /onlinevideos?format=json
   ```
   Retorna:
   ```json
   {
     "channels": [
       {
         "channel_id": "UCxxx",
         "title": "LouvorJA",
         "custom_url": "@louvorja",
         "default_image": "https://...",
         "default_image_base64": "..."
       }
     ],
     "playlists": [...],
     "videos": [...]
   }
   ```

### Parâmetros

| Parâmetro | Descrição | Valores |
|-----------|-----------|---------|
| `format` | Formato de saída | `sql` (default) ou `json` |
| `lang` ou `id_language` | Idioma | `pt` (default), `es`, `en` |
| `tipo` | Tipo de dados | `canais`, `playlists`, `videos`, `tudo` (default) |
| `id` | Filtro por ID | Canal ID, Playlist ID ou Video ID |

### Exemplos

```
GET /onlinevideos?format=json&lang=pt&tipo=tudo
GET /onlinevideos?format=json&lang=es&tipo=canais
GET /onlinevideos?lang=en&tipo=playlists&id=UCxxx
```

### Backward compatibility

O formato SQL continua funcionando sem mudança. O parâmetro `?format=json` é opcional e permite integração moderna com Electron/VueJS enquanto mantém compatibilidade com o Delphi Desktop.

**Adicionado em:** 2026-06-23 (versão controlada via PR)

---

## API para Sugestão de Hinos — Capacidades e Gaps

Análise de como os endpoints existentes suportam um sistema de sugestão de hinos (e o que falta).

### Dados disponíveis para sugestão

| Endpoint | Dado útil para sugestão | Acesso |
|----------|------------------------|--------|
| `/json_db/pt_musics` | Index completo (nome, ID, idioma, categoria) | Api-Token |
| `/json_db/pt_hymnal` | Hinário Cantor Cristão (completo) | Api-Token |
| `/json_db/pt_hymnal_1996` | Hinário Adventista 1996 (completo) | Api-Token |
| `/json_db/pt_categories` | Categorias com slug e tipo | Api-Token |
| `/json_db/album_{id}` | Albuns temáticos (jovens, louvor, etc) | Api-Token |
| `/json_db/music_{id}` | Letra por estrofes + slide + timing | Api-Token |
| `/musics?q={termo}` | Busca textual pelo nome (paginado) | JWT |
| `/hymnals` | Filtra músicas com categoria slug=hymnal | Público (sem auth) |
| `/json_db/bible_{ver}_{livro}_{cap}` | Texto bíblico — permite cross-ref com hinos | Api-Token |

### Gaps que limitam a sugestão inteligente

1. **Sem campo de tema/tag no model Music** — `Music.php` só tem `name`, `id_file_image`, `id_file_music`, `id_file_instrumental_music`, `id_language`. Busca textual é só pelo nome. Não é possível filtrar por "adoração", "graça", "esperança" etc.
2. **Sem endpoint de recomendação** — Não existe `/suggest?theme=X&occasion=Y`. Teria que ser montado no lado do agente com busca por nome + heurísticas do LLM.
3. **JSONs estáticos podem estar desatualizados** — Os arquivos em `/json_db/` são exportações geradas pela task `export_database_json`. Se a task não rodou recentemente, dados ficam stale.
4. **Sem relacionamento direto música↔tema bíblico** — Não há tabela que associe músicas a passagens bíblicas ou temas litúrgicos.

### Estratégia prática para um agente sugerir hinos com a API

1. Carregar `/json_db/pt_musics` para ter o index completo
2. Usar `/json_db/pt_categories` para entender categorias disponíveis
3. Usar `/hymnals` para sugestões de hinários (público, sem auth)
4. Cross-ref com `/json_db/bible_{ver}_{livro}_{cap}` para basear sugestão no texto do culto
5. Aplicar matching por nome + conhecimento do LLM sobre hinódia para complementar a busca limitada por nome

**Veredito:** Melhora de "chute baseado em conhecimento do LLM" para "dado verificável do acervo real", mas o ganho é incremental pela falta de tags/temas. Um endpoint `/suggest` dedicado com embeddings seria o próximo nível.

---

## Fluxo de Dados Detalhado

```
npm run dev (porta 5002)
     │
     ▼
Vite lê .env → injeta import.meta.env
     │
     ▼
Frontend faz fetch para VITE_URL_DATABASE/{arquivo}
     │
     ▼
Header Api-Token enviado em cada request
     │
     ▼
Servidor retorna JSON
     │
     ▼
Response salva no sessionStorage (cache)
     │
     ▼
Componentes leem do cache (db:{nome})
```

---

## Scripts Padrão Telegram (em `/home/ubuntu/telegram-client/`)

### 1. Buscar Mensagens de Usuário Específico
```python
#!/usr/bin/env python3
"""Busca todas as mensagens de um usuário específico nos últimos dias."""
import asyncio
from datetime import datetime, timedelta
from telethon import TelegramClient

API_ID = 24186295
API_HASH = "97eb670a37eee57df5da8b43a6627ab4"
SESSION = "louvor_ja_session"
CHAT_ID = -1002108908408

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.connect()

    if not await client.is_user_authorized():
        print("ERRO: Session não autorizada")
        await client.disconnect()
        return

    entity = await client.get_entity(CHAT_ID)
    limit = 500
    start_date = datetime.now() - timedelta(days=7)

    async for message in client.iter_messages(entity, limit=limit):
        if message.date < start_date:
            break
        if message.sender and message.sender.username == "Ajegado":
            print(f"[{message.date}] {message.text[:100]}")

    await client.disconnect()

if __name__ == '__main__':
    asyncio.run(main())
```

**Uso:**
```bash
cd /home/ubuntu/telegram-client && python3 check_diego.py
```

### 2. Responder no Grupo
```python
#!/usr/bin/env python3
"""Envia mensagem para o grupo de devs."""
import asyncio
from telethon import TelegramClient

API_ID = 24186295
API_HASH = "97eb670a37eee57df5da8b43a6627ab4"
SESSION = "louvor_ja_session"
CHAT_ID = -1002108908408

MENSAGEM = """@Ajegado Adicionei suporte a JSON no endpoint /onlinevideos!

Agora aceita `?format=json` para retorno JSON em vez de SQL."""

async def main():
    client = TelegramClient(SESSION, API_ID, API_HASH)
    await client.connect()

    if not await client.is_user_authorized():
        print("ERRO: Session não autorizada")
        await client.disconnect()
        return

    entity = await client.get_entity(CHAT_ID)
    await client.send_message(entity, MENSAGEM)
    print("Mensagem enviada para o grupo Louvor JA - Dev")

    await client.disconnect()

if __name__ == '__main__':
    asyncio.run(main())
```

**Uso:**
```bash
cd /home/ubuntu/telegram-client && python3 update_diego.py
```

---

## Contexto da Sessão (2026-06-23)

### Mensagens do Diego (Ajegado)
- Perguntou sobre Swagger (se foi implementado e qual URL)
- Perguntou quais URLs estão disponíveis na API
- Pediu para documentar as URLs no README
- Perguntou sobre permissão para criar branch

### Ações Tomadas
1. Clonei louvorja/api e verifiquei PR #11 (Swagger) — ainda aberto
2. Documentei todos os endpoints no README.md
3. Respondi explicando situação do Swagger e permissões GitHub
4. Não consegui dar push — sem permissão no repo
5. Atualizei README localmente, mas não foi enviado

### Conflitos PR #18 (louvorja/desktop)
- Status: CONFLICTING / DIRTY
- Conflito em dmComponentes.dfm (bitmap de ícone)
- Solução: `git rebase origin/main`
- Respondi no grupo explicando o conflito

### Endpoint /onlinevideos
- Adicionado suporte a JSON via `?format=json`
- Mantém backward compatibility (SQL default)
- Documentado nesta skill
- Não foi possível fazer PR — sem permissão de push
