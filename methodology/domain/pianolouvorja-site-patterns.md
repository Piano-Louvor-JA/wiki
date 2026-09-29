# Pianolouvorja Site Patterns

> **Metodologia pública** — padrões do site (Nuxt 3). Aplica-se a qualquer stack.

---
Repo: `Piano-Louvor-JA/site` — site oficial do PIANO LouvorJA.
Stack: **Nuxt 3** + Vue 3 + SSR + Firebase Auth + Vite.

Diferente de `Piano-Louvor-JA-web-feature-patterns` (que cobre o web app Vue 3 SPA com Vuetify). Este cobre o site Nuxt 3 com SSR.

## Estrutura do Projeto

```
app/
  components/     # AdminChart, NewsletterForm, etc
  composables/    # useAppHead (SEO/meta), useFirebaseAuth, useNewsletter
  pages/
    index.vue     # Landing
    download.vue  # Downloads (GitHub releases API)
    admin/
      index.vue   # Dashboard com cards + charts
      newsletter.vue # Compose, subscribers, history, status
      login.vue
    contact.vue, privacy.vue, terms.vue, docs.vue
  layouts/
    default.vue, admin.vue
  plugins/
    apexcharts.client.ts  # Plugin global ApexCharts
  types/
    apexchart.d.ts        # Type declaration global
server/
  api/
    admin/
      newsletter/
        send.post.ts       # Batch send (50/batch, 2s delay)
        send-test.post.ts  # Single test email
        preview.post.ts    # Live template preview (renders HTML server-side)
        subscribers.get.ts # Lista de assinantes (Buttondown API)
        status.get.ts      # SMTP + subscriber count
    stats/                 # Dashboard stats endpoints
  utils/
    email-templates.ts     # 3 templates: announcement, release, devocional
    subscribers.ts         # Buttondown API client
    dashboard-stats.ts
  routes/
    sitemap.xml.ts         # Sitemap dinamico
public/
  robots.txt               # Sitemap: https://Piano-Louvor-JA.com.br/sitemap.xml
```

## Firebase Admin (Server-Side)

### firebase-admin v14 modular API (CRITICAL)

O projeto usa `firebase-admin@14.2.0`. A API mudou -- os metodos NAO estao mais no top-level do modulo.

**ERRADO (v9-v13 API):**
```js
const admin = require('firebase-admin')
admin.initializeApp({ credential: admin.credential.cert(key) })  // undefined
admin.auth()  // TypeError: admin.auth is not a function
```

**CERTO (v14 modular):**
```js
const { initializeApp, cert } = require('firebase-admin/app')
const { getAuth } = require('firebase-admin/auth')

initializeApp({ credential: cert(serviceAccount) })
const auth = getAuth()
```

Verificacao rapida: `node -e "const admin = require('firebase-admin'); console.log(Object.keys(admin))"` -- se retorna `['initializeApp', 'cert', ...]` SEM `auth` ou `credential`, e a API modular.

### Password Reset via Admin SDK

Para resetar a senha de um usuario do Firebase Auth a partir da VM:

1. Obter a service account key (Firebase Console ou via Tailscale SCP da maquina Windows: `/mnt/c/Users/<user>/Downloads/...`)
2. Script `.cjs` (NAO `.js` -- o projeto tem `"type": "module"`, `require()` so funciona em `.cjs`):

```js
// reset-password.cjs
const { initializeApp, cert } = require('firebase-admin/app')
const { getAuth } = require('firebase-admin/auth')
const serviceAccount = require('./firebase-key.json')

initializeApp({ credential: cert(serviceAccount) })
const auth = getAuth()

auth.getUserByEmail('rafael.zendron@Piano-Louvor-JA.com.br')
  .then(user => auth.updateUser(user.uid, { password: 'NewPassword123!' }))
  .then(() => { console.log('Password updated'); process.exit(0) })
  .catch(err => { console.error(err.message); process.exit(1) })
```

3. Rodar e **limpar imediatamente** (a key JSON nunca deve permancer no servidor):
```bash
node reset-password.cjs
rm -f firebase-key.json reset-password.cjs
```

### Configuracao Firebase no projeto

- Client: `app/composables/useFirebaseClient.ts` (getAuth, signInWithEmailAndPassword)
- Auth wrapper: `app/composables/useFirebaseAuth.ts` (login, logout, getToken)
- Server Admin: `server/utils/firebase-admin.ts` (usa `useRuntimeConfig().firebaseServiceAccount`)
- Runtime config: `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, etc. + `FIREBASE_SERVICE_ACCOUNT` (JSON inline)
- Admin access: `ADMIN_EMAILS` env var (comma-separated)

### PITFALL: .env incompleto = "credenciais invalidas" (nao e a senha)

O `useFirebaseClient.ts` faz uma guarda no inicio:

```ts
if (!config.firebaseApiKey || !.config.firebaseAppId) {
  throw new Error('Firebase configuration missing. Check your .env file.')
}
```

Se o `.env` da VM/producao nao tiver TODAS as variaveis publicas do Firebase, o client
nao inicializa o Firebase Auth. O usuario ve "credenciais invalidas" e tenta resetar a
senha -- mas a senha esta certa. O problema e que o Firebase nunca inicializou.

**Variaveis OBRIGATORIAS no `.env`:**

```
FIREBASE_API_KEY=***
FIREBASE_AUTH_DOMAIN=Piano-Louvor-JA.firebaseapp.com
FIREBASE_PROJECT_ID=Piano-Louvor-JA
FIREBASE_STORAGE_BUCKET=Piano-Louvor-JA.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=267038930810
FIREBASE_APP_ID=1:267038930810:web:...
FIREBASE_SERVICE_ACCOUNT={...JSON inline...}
ADMIN_EMAILS=rafael.zendron@Piano-Louvor-JA.com.br,ezequiasfonseca@gmail.com
```

**Diagnostic flow quando login falha:**
1. Checar se `.env` tem todas as vars acima (NAO so a service account)
2. Reiniciar o dev server apos mudar `.env` (Nuxt nao recarrega env vars em hot-reload)
3. Se a senha foi resetada e ainda falha, setar `emailVerified: true` via Admin SDK
4. So então suspeitar da senha em si

### Password Reset Email Flow (Client-Side — "Esqueci minha senha")

O Firebase Auth tem `sendPasswordResetEmail()` nativo que envia email de noreply com link de reset. O usuario clica no link e define a nova senha na pagina do Firebase (nao na nossa app).

**Implementacao no `useFirebaseAuth.ts`:**

```ts
import { sendPasswordResetEmail } from 'firebase/auth'

async function sendPasswordReset(email: string) {
  error.value = null
  if (!auth) throw new Error('Firebase not initialized')
  await sendPasswordResetEmail(auth, email)
}
```

**UI na `login.vue` — padrao toggle entre login e reset:**

- `resetMode = ref(false)` controla modo
- Quando `resetMode=true`: esconde campo de senha, mostra so email
- Submit chama `sendPasswordReset(email)` em vez de `login(email, password)`
- `resetSent = ref(false)` mostra tela de sucesso ("enviamos um link para...")
- Botoes "Esqueci minha senha" / "Voltar ao login" alternam `resetMode`

**O email vem de:** `noreply@Piano-Louvor-JA.firebaseapp.com` (ou similar). Para customizar o dominio do remetente, configurar no Firebase Console > Authentication > Templates.

**LICAO:** NAO criar pagina propria de reset de senha. O `sendPasswordResetEmail` ja envia o link do Firebase que abre a pagina de reset nativa deles. So precisamos do botao que dispara o envio do email.

### emailVerified: false como causa de auth failure

Ao resetar senha via Admin SDK, setar tambem `emailVerified: true` e `disabled: false`
para eliminar essa variavel:

```js
auth.updateUser(user.uid, {
  password: 'NewPassword123',
  emailVerified: true,
  disabled: false
})
```

## Deploy

- **Hostinger** (producao): env vars no painel
- **Dev**: `.env` local (gitignored), `.env.example` e template publico
- **Tunnel dev**: cloudflared para validacao manual (ver cloudflare-tunnel-testing)

## ApexCharts v3 (CRITICAL PITFALLS)

Ver `references/apexcharts-nuxt3.md` para detalhes completos.

**Versoes corretas:** apexcharts@^3.54.0, vue3-apexcharts@1.11.1

### NAO usar ApexCharts v6
v6 crasha com Vite HMR: `Cannot read properties of undefined (reading 'line')` em `Globals.globalVars`. Downgrade para v3 e obrigatorio.

### chartOptions DEVE ser computed<ApexOptions>
Objeto plano captura props uma vez no setup. Quando props mudam (troca de card/filtro), ApexCharts recebe dados stale e quebra com `Unhandled error during watcher callback`.

```ts
// ERRADO — captura props.category uma unica vez
const chartOptions = { xaxis: { categories: props.categories } }

// CERTO — recria quando props mudam
const chartOptions = computed<ApexOptions>(() => ({
  xaxis: { categories: props.categories },
  // ...
}))
```

### :key no apexchart para remount limpo
O key DEVE ser unico por metrica+periodo. Se duas metricas compartilham o mesmo type (ex: donations e newsletter ambos 'bar') e as mesmas categories (monthLabels no 12m), o key colide e o Vue nao remonta.

Solucao em 2 niveis:

```vue
<!-- PARENT (admin/index.vue): key unico por metrica+filtro -->
<AdminChart
  :key="activeView + chartFilter"
  :type="getChart(activeView).type"
  ...
/>

<!-- CHILD (AdminChart.vue): key por numero de categorias (remount ao trocar periodo) -->
<apexchart
  :key="categories.length"
  :type="type"
  ...
/>
```

NAO usar `:key="type + categories.join()"` no child apenas -- colide entre metricas com mesmo type.

### Plugin global (nao defineAsyncComponent)
`defineAsyncComponent` nao registra o componente a tempo no dev mode. Usar plugin Nuxt:

```ts
// app/plugins/apexcharts.client.ts
import VueApexCharts from 'vue3-apexcharts'
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.vueApp.use(VueApexCharts)
})
```

Registra 3 componentes globais: `apexchart`, `apexchart-server`, `apexchart-hydrate`.

### Type declaration global
```ts
// types/apexchart.d.ts
import type { DefineComponent } from 'vue'
declare module '@vue/runtime-core' {
  export interface GlobalComponents {
    apexchart: DefineComponent<Record<string, unknown>, Record<string, unknown>>
  }
}
```

### Sempre dentro de ClientOnly
ApexCharts manipula DOM diretamente. Sempre wrap com `<ClientOnly>` para evitar SSR errors.

## Mock Data DEV-ONLY (import.meta.dev)

**REGRA:** dados mock para desenvolvimento NAO devem ir para producao.

Usar `import.meta.dev` guard — Vite tree-shake remove o bloco em production builds:

```ts
const mockData = import.meta.dev
  ? { /* dados mock */ }
  : {}
```

**PITFALL:** Subir mock data hardcoded como objeto estatico no repo e erro. Sempre gatear com `import.meta.dev`.

## Design Tokens e Branding (CRITICAL)

O site tem DOIS arquivos CSS com tokens DIFERENTES. Usar o correto:

| Arquivo | Status | Uso |
|---------|--------|-----|
| `app/assets/css/main.scss` | **CORRETO** | Sistema `--piano-*` — usar SEMPRE |
| `assets/css/main.css` | **LEGADO/ERRADO** | Tokens `--color-*` (#1a56db etc) — NAO usar |

### Tokens reais da marca (--piano-*)

```
Cores primarias:
  --piano-blue-deep:  #10438c   (azul do logo)
  --piano-blue:       #04549b
  --piano-blue-light: #0a6bc2
  --piano-cyan:       #00c1e6   (destaque, links)
  --piano-cyan-light: #5dd9f0
  --piano-yellow:     #fcce02   (amarelo do logo)
  --piano-yellow-dark:#e0b800

Backgrounds:
  --piano-dark:       #0a1733   (bg dark)
  --piano-slate:      #1e2a45
  --piano-gray-700:   #475569
  --piano-gray-500:   #64748b
  --piano-gray-300:   #cbd5e1
  --piano-gray-100:   #f1f5f9

Tipografia: Inter (sans-serif)
Border radius: 8px / 16px
```

### PITFALL: Email templates com cores erradas

Os templates em `server/utils/email-templates.ts` usam cores Tailwind que NAO batem com a marca:
- `#22d3ee` (cyan Tailwind) → deveria ser `#00c1e6` (--piano-cyan)
- `#f59e0b` (amber Tailwind) → deveria ser `#fcce02` (--piano-yellow)
- `#0a0e1a` → deveria ser `#0a1733` (--piano-dark)

### Logos SVG disponiveis

```
public/brand/logo-louvor-ja.svg       (7KB)  — logo principal (azul #10438c + amarelo #fcce02)
public/brand/logo-louvor-agrupado.svg (12KB) — logo + codename agrupado
public/brand/codename-piano.svg       (16KB) — so o codename PIANO
```

Usar em emails via `<img src="https://Piano-Louvor-JA.com.br/brand/logo-louvor-ja.svg">` no header.

Ver `references/brand-design-system.md` para mapeamento completo de cores.

## i18n e Internacionalizacao de Emails

O site tem `@nuxtjs/i18n` v10 com 3 locales (pt-BR, en, es), arquivos JSON em `assets/i18n/{pt-BR,en,es}.json` (NAO em `/i18n/`).
`detectBrowserLanguage` com cookie `piano_lang`. Ja tem keys de newsletter traduzidas nos 3 idiomas.

### GAP: Email templates sao hardcoded pt-BR

O `Subscriber` interface NAO tem campo `locale`. Buttondown API nao retorna idioma.
Templates de email tem strings fixas ("Cancelar inscricao", "Todos os direitos reservados").

### Plano de i18n para emails

1. Capturar `useI18n().locale.value` no signup do formulario de newsletter
2. Guardar no subscriber metadata (Buttondown `metadata` field ou Firebase)
3. `renderTemplate()` recebe `locale` param e usa strings i18n do footer/header
4. Corpo do email continua sendo o que o admin escreve — traducao automatica de conteudo precisa de LLM/API

### Browser NAO traduz email
Email clients (Gmail, Outlook) nao traduzem. O email chega no idioma em que foi enviado.

## SEO / Google Search Console

Google site verification em `app/composables/useAppHead.ts`:
```ts
{ name: 'google-site-verification', content: 'A0OHlivpSyISUwtfHocbr3ESg1ShWBjjUSmRvaC0exQ' },
```

Sitemap dinamico em `server/routes/sitemap.xml.ts`.
robots.txt em `public/robots.txt` aponta para `https://Piano-Louvor-JA.com.br/sitemap.xml`.

## Email Template Preview (PADRAO)

Para preview de templates de email no admin dashboard:

1. **Endpoint server-side**: POST que recebe `{ template, subject, body }` e retorna `{ html }` usando a mesma `renderTemplate()` do envio real. Preview = inbox real.

2. **Frontend com iframe sandboxed**: NUNCA fazer `v-html` direto do HTML de email no DOM do dashboard. CSS do email (dark theme, tables) conflita com o CSS da pagina. Usar `<iframe :srcdoc="html" sandbox="" />`.

3. **Debounce de 500ms**: `watch([subject, body, template], () => { clearTimeout(timer); timer = setTimeout(fetchPreview, 500) })`. Evita spammar o servidor a cada tecla.

4. **Cleanup no unmount (CRITICAL)**: O timer do debounce DEVE ser limpo com `onBeforeUnmount`. Sem isso, se o usuario troca de aba antes do debounce terminar, o timer dispara num componente ja desmontado -- memory leak + warning Vue.

```ts
let previewTimer: ReturnType<typeof setTimeout> | null = null

function schedulePreview() {
  if (previewTimer) clearTimeout(previewTimer)
  previewTimer = setTimeout(fetchPreview, 500)
}

watch([subject, body, template], schedulePreview)

onBeforeUnmount(() => {
  if (previewTimer) clearTimeout(previewTimer)
})
```

Ver `references/newsletter-system.md` para detalhes completos do sistema de newsletter.

## Newsletter: Server-Side Proxy (RESOLVIDO em PR #24)

### Arquitetura do fluxo de subscribe (pos-fix)

```
Client (NewsletterForm / NotifyModal)
  → POST /api/newsletter/subscribe { email, metadata: { locale } }
    → server/api/newsletter/subscribe.post.ts
      → handleSubscribe(event)
        1. Valida API key (runtimeConfig.buttondownApiKey — privado)
        2. readBody + validateSubscribeBody (pure function)
        3. $fetch Buttondown com Authorization: Token <key> (server-side)
        4. catch → mapButtondownError(err) → error code
        5. throw createError({ statusCode, statusMessage, data: { code } })
    ← { success: true } ou structured error
```

### O que mudou

1. **`buttondownApiKey` e `buttondownEndpoint` REMOVIDOS do `runtimeConfig.public`**
   — agora so existem no nivel privado do runtimeConfig. O cliente nunca ve a key.

2. **Novo endpoint: `server/api/newsletter/subscribe.post.ts`** — proxy server-side.
   Exporta funcoes puras para teste:
   - `validateSubscribeBody(body)` → retorna `'invalid-email'` ou `null`
   - `mapButtondownError(err)` → mapeia erros Buttondown para error codes
   - `handleSubscribe(event)` → handler principal (usa readBody + createError do Nitro)

3. **`useNewsletter.ts` agora chama `/api/newsletter/subscribe`** (nao Buttondown direto).
   Error mapping mudou: agora le `data.code` da resposta estruturada do server.

4. **NotifyModal.vue agora tem `errorI18nKeyMap` + `displayError` computed** — igual
   NewsletterForm ja tinha. Template usa `{{ displayError }}` (traduzido) nao `{{ errorMessage }}` (cru).

### LICAO: Server API endpoints testaveis em Nuxt/Vitest

Endpoints Nitro (`server/api/*.ts`) usam `defineEventHandler`, `readBody`, `createError`
como **auto-imports do Nitro** — nao sao importados explicitamente. Em testes Vitest:

1. **Stubar auto-imports no `test/setup.ts`** (NAO no test file individual):
   ```ts
   vi.stubGlobal('defineEventHandler', <T>(handler: T) => handler)
   // readBody e createError precisam de stubs locais no test file que os usa
   ```

2. **Extrair logica em funcoes puras exportadas** — sem dependencias de h3:
   ```ts
   // Exportadas e testaveis sem mockar h3:
   export function validateSubscribeBody(body): string | null { ... }
   export function mapButtondownError(err): string { ... }
   // Handler que usa h3 auto-imports — testado com stubs globais:
   export async function handleSubscribe(event) { ... }
   ```

3. **NAO usar `vi.mock('h3')`** — o Vite tenta resolver o modulo `h3` antes do mock
   interceptar. No CI (pnpm), `h3` pode nao estar na raiz de node_modules. Sintomas:
   `Failed to resolve import "h3" from "test/..."`.

4. **Stub de readBody/createError no test file** (nao no setup global — quebra integration tests):
   ```ts
   const globalReadBody = vi.fn(async () => mockReadBody)
   const globalCreateError = vi.fn((opts) => { ... })
   vi.stubGlobal('readBody', globalReadBody)
   vi.stubGlobal('createError', globalCreateError)
   ```

5. **`/* istanbul ignore next */` no `export default defineEventHandler(...)`** — a linha
   nao e executavel em testes (defineEventHandler e stub), gera branch coverage irrelevante.

6. **`vi.stubGlobal` em test file individual QUEBRA integration tests** se colocado em
   `test/setup.ts` — os testes de integracao rodam num project separado mas compartilham
   o processo. Stubs de `readBody`/`createError` devem ficar SO no test file que precisa.

### LICAO: Quando dois componentes compartilham um composable com error codes

NewsletterForm e NotifyModal usam `useNewsletter()` que retorna `errorMessage` como
error code bruto (ex: `service-unavailable`). AMBOS precisam do mesmo `errorI18nKeyMap`
+ `displayError` computed. Centralizar o mapa evita divergencia — um componente mostra
traduzido, o outro mostra o code cru.

### Coverage de NotifyModal.vue — branch do computed displayError

O `displayError` computed tem `if (!errorMessage.value) return ''`. Essa linha so e
avaliada quando `v-if="isError"` e true. Para cobrir: setar `status='error'` +
`errorMessage=''` no reactive state e mountar o componente.

## Git Workflow

Branch feature a partir de `main` (NAO staging como no web app):
```bash
git checkout main && git pull origin main
git checkout -b feat/my-feature
```

`--no-verify` no push quando lint-staged local esta quebrado:
```bash
git push --no-verify origin feat/my-feature
```

### Commitlint rules (CRITICAL)

O repo tem commitlint com conventional-commits. Regras que pegam:

- **Subject em lowercase obrigatorio**: `fix(admin): QA fixes` REJEITA. Usar `fix(admin): qa fixes`.
- **Sem sentence-case, start-case, pascal-case, upper-case** no subject.
- Formato: `type(scope): lowercase description`

Hooks: husky pre-commit (lint-staged: eslint --fix + prettier --write) + commit-msg (commitlint).

## Downloads por arquitetura (arm64 vs x64) — PR #44

O release v1.26.0+ do `Piano-Louvor-JA/app` publica assets por arquitetura:
`arm64.dmg` + `x64.dmg`, `arm64.AppImage` + `x86_64.AppImage`. Regras
(implementadas em `app/utils/downloads.ts` + `device-detection.ts`):

- **Matchers por arch**: keys `macos-arm64`, `macos-x64`, `linux-arm64`,
  `linux-x64`. Asset legado SEM sufixo de arch (ex: `PIANO-1.17.5.dmg`)
  = build único da era Intel → mapear pra `x64`.
- **Detecção de arch**: o User-Agent de Macs NÃO expõe a arquitetura real
  (Chrome/Safari reportam 'Intel' até em Apple Silicon por retrocompat).
  Única fonte confiável: `navigator.userAgentData.getHighEntropyValue(['architecture'])`
  → retorna `'arm'` em Silicon (ver `parseArch`/`detectArch` em
  `app/utils/device-detection.ts`). Safari/Firefox não têm userAgentData →
  fallback `x64` (maior base instalada).
- **Link alternativo SEMPRE visível** ("Baixar para {arch}", i18n
  `download.desktop.otherArch` em `i18n/{pt-BR,en,es}.json` — NÃO
  `assets/i18n/`): erro de detecção se corrige a 1 clique.
- **PITFALL — v-if/v-else-if/v-else chain**: NÃO inserir elementos novos
  NO MEIO de uma cadeia condicional de botões. Inserir um `v-if` próprio
  no meio quebra o encadeamento — o `v-else` seguinte passa a encadear no
  elemento novo e renderiza botões duplicados (bug do botão Windows
  duplicado, visto em screenshot no túnel da PR #44). Inserir DEPOIS do
  fechamento da cadeia, como bloco independente.
- **PITFALL — teste de UI por contagem de href não pega duplicação
  visual**: o teste contava hrefs com filtro e passou com o bug ativo.
  Mudança em cadeia condicional de UI → validar com screenshot
  (`npx playwright screenshot <url> file.png --full-page`) + análise
  visual, ou asserção estrutural do DOM do card.
- CI e husky: pre-commit (lint-staged) pode falhar com `lint-staged\r`
  (CRLF do .husky em checkout Windows→WSL) — usar `git commit --no-verify`
  e `git push --no-verify`.

## Issues Abertas (roadmap)

- #15 - Documentacao da API (/docs/api)
- #14 - Cache invalidation no dashboard admin
- #10 - Compatibilidade com TVs (Cast, DLNA, AirPlay)
- #9 - Atalhos dinamicos via GitHub API
- **TODO**: Pagina /unsubscribe com confirmacao + endpoint server-side (unsubscribeUrl nos emails aponta para homepage sem confirmacao — user levantou a issue em 08/08/2026)

### Issues fechadas (redirecionadas)

- #13 - Hinario CCB — fechada, projeto futuro, nao pertece ao escopo do site
- #12 - Fontes proprias (sda-hymnal NPM + SacCentral + MIDI) — fechada, migrada para `Piano-Louvor-JA/api` (ja existe la como #4 + #14)
- #11 - API propria v1 — fechada, migrada para repo dedicado `Piano-Louvor-JA/api` (Hono + Zod OpenAPI + SQLite)

### Organizacao da org Piano-Louvor-JA (repos ativos)

| Repo | Responsabilidade | Stack |
|------|-----------------|-------|
| `Piano-Louvor-JA/app` | Desktop Electron multi-tela PERMANENTE | Electron |
| `Piano-Louvor-JA/web` | PWA Vue 3 SPA | Vue 3 + Vuetify |
| `Piano-Louvor-JA/site` | Site oficial (landing, docs, blog) | Nuxt 3 + SSR |
| `Piano-Louvor-JA/api` | REST API para hinarios | Hono + Zod + SQLite |
| `Piano-Louvor-JA/apk` | Mobile Flutter (fork local `~/Piano-Louvor-JA-flutter/src`) | Flutter/Dart |
| `Piano-Louvor-JA/palco-receiver` | Receiver de TV (webOS/Tizen/AndroidTV/browser) | HTML/JS + Flutter WebView |
| `Piano-Louvor-JA/api` (palco relay) | WS relay + custom catalog (mesmo repo api) | Hono |

**REGRA:** Features de API (proxy, cache, endpoints de dominio) vao em `Piano-Louvor-JA/api`, NAO no site. O site consome a API, nao a implementa.

## CI/CD Pipeline (GitHub Actions)

O repo tem 8 jobs de CI que rodam em cada push/PR:

| Job | Tempo medio | Observacao |
|-----|------------|------------|
| Auto-label PR | ~6s | Rapido, sempre passa |
| Lint + Typecheck + Test | ~2m20s | ESLint + nuxt typecheck + vitest |
| SSG Build | ~40s | Nuxt generate |
| Storybook Build | ~39s | Build do Storybook |
| A11y + Lighthouse Audit | ~1m30s | Accessibility + SEO audit |
| E2E Tests (Playwright) | ~2m | Integration tests |
| SonarQube Analysis | ~2m | Code quality + coverage |
| Mutation Testing (Stryker) | ~5-6m | **GARGALO** -- mais lento |

Tempo total: ~6-8min para tudo completar. O Mutation Testing e sempre o ultimo.

### Monitorar CI apos push

```bash
# Ver status de todos os jobs
gh pr checks <PR_NUMBER>

# Sair do loop de espera (exit code 8 = pending, 0 = all pass)
# Esperar manualmente:
sleep 180 && gh pr checks <PR_NUMBER>
```

### Pre-push hook (husky) -- TIMING PITFALL

O husky pre-push roda: eslint -> prettier -> nuxt typecheck -> vitest run.

O `vitest run` completo (708 testes, 42 arquivos, incluindo integration) demora ~3-5min
localmente. O hook **timeout em 60s** se configurado com timeout padrao, bloqueando o push.

**Solucao:** usar `--no-verify` no push. O CI no GitHub vai rodar tudo de qualquer forma:

```bash
git push --no-verify origin feat/my-feature
```

NAO pular o pre-commit (lint-staged + commitlint) -- so o pre-push.

## Testing e Coverage (Nuxt 4 + Vitest)

O projeto tem vitest com dois projects: `unit` (happy-dom) e `integration` (node).

### Coverage timeout

Coverage combinada (`npx vitest run --coverage`) pode timeout porque integration
tests batem na GitHub API (rate limit). Isolar:

```bash
npx vitest run --project unit --coverage
```

### Gaps comuns de coverage neste projeto

- **AdminChart.vue** (0% coverage): precisa stubar `apexchart` em `global.stubs` e
  testar computed series/options. Ver `references/nuxt4-coverage-isolation-and-plugin-testing.md`
  na skill `vitest-coverage-workflow`.
- **apexcharts.client.ts** (linha do plugin): usar `vi.stubGlobal('defineNuxtPlugin', fn => fn)`
  para desembrulhar e chamar com `{ use: vi.fn() }`.
- **email-templates.ts** (inCode block + badge fallback): alimentar markdown com code fences
  e template desconhecido.
- **llm-translate.ts** (`config.llmModel ?? default`): mock useRuntimeConfig sem `llmModel`.
- **useNewsletter.ts** (rate-limited / service-unavailable): mock `$fetch` reject com
  statusCode 429 e 503. Tambem cobrir patterns: `timeout`, `fetch failed`, `ECONNREFUSED`,
  `ECONNRESET`, `network`. Ver `references/newsletter-system.md` para a tabela completa
  de error codes.

### PITFALL: Coverage de branches -- nullish coalescing (`??`) dentro de Array.map

`extractDetail` em `subscribe.post.ts` tem 3 caminhos: string, array, e fallback `return ''`.
Dentro do caminho array, ha `rawDetail.map((d) => d?.detail ?? '').join(' ')`. O `?? ''` cria
DOIS branches: (a) `d.detail` existe (retorna a string) e (b) `d.detail` e undefined/null (retorna `''`).

Testes que passam arrays onde TODOS os elementos tem `.detail` (ex: `[{ detail: 'msg' }]`)
cobrem SO o caminho (a). Para 100% branches, precisa de UM teste com array onde o item
NAO tem `.detail`:

```ts
it('maps error with array detail where item has no detail property to service-unavailable', () => {
  expect(mapButtondownError({ data: { detail: [{ code: 'x' }] } })).toBe('service-unavailable')
})
```

Isso forca `d?.detail` a ser `undefined`, caindo no `?? ''` (caminho b).

Licao geral: optional chaining (`?.`) e nullish coalescing (`??`) dentro de `.map()` geram
branches que coverage tools (v8/istanbul) rastreiam. Cobrir so o happy path do array
nao e suficiente -- precisa exercitar o caso onde a propriedade encadeada esta ausente.

### PITFALL: mapErrorToCode intercepta "network" em mensagens de erro

O `mapErrorToCode()` em `useNewsletter.ts` faz string matching em erros para classificar.
A palavra "network" aparece no matcher de `service-unavailable`. Se um teste mocka um erro
com mensagem contendo "network" mas espera um code diferente (ex: `subscribe-failed`),
o teste falha porque o mapa intercepta e retorna `service-unavailable`.

Solucao: em testes, usar mensagens de erro que NAO colidem com os matchers do mapErrorToCode.
Evitar: "network", "timeout", "fetch failed", "ECONNREFUSED", "ECONNRESET", "rate limit",
"too many", "already subscribed", "email_address" -- a menos que seja exatamente o cenario
sendo testado.

### Coverage 100% em NewsletterForm.vue -- caso do computed nao avaliado

O `displayError` computed so e avaliado quando o template renderiza com `v-if="isError"`.
Se nenhum teste forca `status='error'` + `errorMessage=''`, a linha `if (!errorMessage.value) return ''`
nunca e executada. Para cobrir: setar status e errorMessage diretamente no reactive state
e chamar a avaliacao do computed.

Para detalhes completos de patterns de teste, ver skill `vitest-coverage-workflow` >
`references/nuxt4-coverage-isolation-and-plugin-testing.md`.

## Warnings Conhecidos (NAO bloqueantes)

- `onMounted is called when there is no active component instance` em `useFirebaseAuth.ts:21` — pre-existente, nao relacionado a charts
- `contentscript.js` / `contentScript.js` errors — extensao Chrome (MetaMask/wallet), nao do codigo
- `MaxListenersExceededWarning` — tambem da extensao Chrome
