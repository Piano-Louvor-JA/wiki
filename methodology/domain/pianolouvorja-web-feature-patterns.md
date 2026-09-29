# Pianolouvorja Web Feature Patterns

> **Metodologia pública** — padrões de implementação de features no web. Aplica-se a qualquer stack.

---
Padroes recorrentes ao implementar features no Piano-Louvor-JA/web. Para repo management, CI/CD e releases ver `Piano-Louvor-JA-web-repo-workflow`. Para design system e UI ver `Piano-Louvor-JA-ui-patterns`.

## Vitest Config

### Padrao: embutido em vite.config.ts (repo-wide)

Para config geral de testes do repo, manter embutido no `vite.config.ts`:

```ts
/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
  },
})
```

PITFALL: `import type { UserConfig } from 'vitest/config'` quebra `vue-tsc --build`. Use `/// <reference types="vitest/config" />`.

### `vitest.config.ts` separado SOBREPÕE `vite.config.ts`

Vitest não herda aliases nem `test.environment` do `vite.config.ts` quando há `vitest.config.ts`. Replicar TODOS os aliases do Vite (`@`, `@app`, `@modules`, `@shared`, `@design-system`, `@layouts`, `@plugins`, `@themes`, `@assets`, `@styles`, `@locales`) e declarar `globals: true` + `environment: 'jsdom'`.

Sintomas: `Cannot find package '@locales/pt-BR'` em suites e `ReferenceError: localStorage is not defined`. Sempre executar a suite completa após alterar config; não culpar a feature nova antes de corrigir o baseline.

### Vitest.config.ts separado para coverage threshold 100%

QUANDO criar `vitest.config.ts` separado: quando precisa enforcear coverage
threshold de 100% num subset de arquivos (ex: codigo novo de uma feature).

O usuario exige 100% coverage (stmts/branches/funcs/lines) em todo codigo novo.
O `vitest.config.ts` separado permite `include` seletivo + `thresholds` bloqueantes:

```ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: { alias: { '@shared': './src/shared' } },
  test: {
    coverage: {
      provider: 'v8',
      thresholds: { lines: 100, functions: 100, statements: 100, branches: 100 },
      include: ['src/shared/composables/useUpdateChecker.ts'],
    },
  },
})
```

O `include` seletivo garante que o threshold so aplica pros arquivos novos.
Rodar: `npx vitest run --coverage`. Se threshold falhar, exit code != 0.

Script no package.json: `"test": "vitest run"` (usa vitest.config.ts se existir,
senao usa vite.config.ts).

### TDD Composable Pattern (100% coverage garantido)

Para alcancar 100% branch coverage em composables Vue:

1. **Dual test files**: jsdom (browser) + node (SSR/no-window)
   - `__tests__/useX.test.ts` com `// @vitest-environment jsdom`
   - `__tests__/useX.ssr.test.ts` com `// @vitest-environment node`

2. **Mocks com `ref()` reais** (nao objetos `{ value: true }`)
   ```ts
   vi.mock('../useX', () => ({ useX: vi.fn() }))
   const mock = { hasUpdate: ref(false), dismiss: vi.fn() }
   vi.mocked(useX).mockReturnValue(mock as any)
   ```

3. **Fake timers para delays auto-init**
   ```ts
   beforeEach(() => { vi.useFakeTimers() })
   it('dispara apos 3s', () => {
     init()
     vi.advanceTimersByTime(3000)
     expect(mock).toHaveBeenCalled()
   })
   ```

4. **Cobrir branches defensivas (typeof guards)**
   - `typeof window === 'undefined'` → teste no env node
   - `typeof sessionStorage !== 'undefined'` → teste no env node
   - `typeof __APP_VERSION__ === 'string'` → eliminar try/catch, usar vite define direto

5. **Eliminar branches impossiveis via refactor**
   - Nullish coalescing (`?? 0`) em array access gera branch que v8 marca como nao coberta
   - Trocar por preenchimento explicito: `while (parts.length < 4) parts.push(0)`
   - Ternarios em loops geram 2 branches cada — preferir arrays preenchidos

### TDD Component Test Pattern (Vue SFC)

Para testar componentes .vue com @vue/test-utils:

```ts
// @vitest-environment jsdom
import { mount } from '@vue/test-utils'
import { ref } from 'vue'
import Component from '../Component.vue'

vi.mock('../../composables/useX', () => ({ useX: vi.fn() }))
import { useX } from '../../composables/useX'

function mockComposable(overrides = {}) {
  const defaults = { visible: ref(false), action: vi.fn() }
  vi.mocked(useX).mockReturnValue({ ...defaults, ...overrides } as any)
}
```

PITFALL: Mocks de composable DEVEM retornar `ref()` reais, nao `{ value: true }`.
Vue template `v-if` so reage a refs reais. Objetos planos nao sao reativos.

## CI do Web NAO Roda Testes

CI roda 3 jobs + quality gate:
1. Lint & Format (`npx biome ci`)
2. Type Check (`vue-tsc --build`)
3. Build (`vite build`)

Testes unitarios devem rodar localmente antes do commit.

## Biome sem Config File

Convencao enforced pelo CI:
- Aspas simples
- Sem semicolons
- `npx biome ci` (nao `check`)

## docs/LEGAL/ no .gitignore

`docs/` esta no `.gitignore`. Para commitar textos legais:
```bash
git add -f docs/LEGAL/
```

### Piramide de Testes Obrigatoria (HARD REQUIREMENT para TODA PR)

REGRA: Toda PR que modifica logica (nao apenas i18n strings) DEVE trazer testes.
O padrao foi estabelecido na PR #83 (EULA, merged) e PR #93 (updater, open).

NIVEIS OBRIGATORIOS:

1. TESTES UNITARIOS (vitest, jsdom)
   - Composable/service: dual env (jsdom + node/SSR)
     - __tests__/useX.test.ts     com `// @vitest-environment jsdom`
     - __tests__/useX.ssr.test.ts com `// @vitest-environment node`
   - Mocks com `ref()` reais (NAO objetos planos `{ value: true }`)
   - Fake timers para delays/auto-init
   - Cobrir branches defensivas (typeof window guards, etc)
   - 100% coverage (stmts/branches/funcs/lines) via vitest.config.ts thresholds

2. TESTES DE COMPONENTE (vitest + @vue/test-utils)
   - `__tests__/Component.test.ts` com `// @vitest-environment jsdom`
   - Mock composables retornando refs reais
   - Testar: render condicional (v-if/v-show), clicks, props, eventos
   - Coverage do .vue entra no threshold 100%

3. TESTES DE INTEGRACAO (vitest)
   - Quando modulo orquestra multiplos services/composables
   - Mock apenas da fronteira externa (fetch, IPC bridge)
   - Validar fluxo end-to-end da feature dentro do modulo

4. MUTATION TESTING (Stryker) — IMPLEMENTADO na PR #103
   - Stryker config: `stryker.config.json` com `@stryker-mutator/vitest-runner`
   - Template: ver `templates/stryker.config.json`
   - Rodar: `npx stryker run` (demora ~2min para 2 arquivos)
   - Thresholds: break=50, low=60, high=80
   - PR #103 resultados: i18n.ts 76% (19 killed, 6 survived), total 54% (81 killed)
   - Reports HTML em `reports/mutation/mutation.html`
   - Adicionar `reports/` e `.stryker-tmp/` ao .gitignore

Estrutura de pastas:
```
src/shared/composables/__tests__/useX.test.ts      (unit jsdom)
src/shared/composables/__tests__/useX.ssr.test.ts   (unit node)
src/shared/components/__tests__/Component.test.ts   (component)
src/modules/<mod>/__tests__/feature.test.ts          (integration)
electron/__tests__/*.test.mjs                        (electron main process)
```

vitest.config.ts SEPARADO do vite.config.ts (quando precisa de coverage threshold):
```ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: { alias: { ...todos os aliases do tsconfig } },
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'text-summary', 'lcov'],
      thresholds: { lines: 100, functions: 100, statements: 100, branches: 100 },
      include: ['src/shared/composables/useX.ts', 'src/shared/components/X.vue'],
    },
  },
})
```

Deps necessarias (instalar se nao existirem):
- vitest (ja instalado)
- @vue/test-utils
- jsdom

PITFALL: `import type { UserConfig } from 'vitest/config'` quebra `vue-tsc --build`. Usar `/// <reference types="vitest/config" />`.

Historico de testes no Piano-Louvor-JA/app:
- PR #83 (EULA, MERGED): electron/__tests__/eula.test.mjs — 243 linhas, unit+integration do Electron main process. vitest instalado.
- PR #93 (updater, OPEN): 3 arquivos de teste + vitest.config.ts com thresholds 100%. Padrao TDD completo.
- PR #103 (i18n + API filter, OPEN): 7 suites, 73 testes total. Primeira PR a trazer
  infra de testes completa para o main (vitest.config.ts, @vue/test-utils, jsdom,
  @stryker-mutator). Piramide: i18n unit (18) + SSR (3) + locale parity (5) +
  GeneralView component (9) + library-catalog unit (14) + integration i18n->catalog
  (6) + eula existente (18). Coverage 100% em i18n.ts. Stryker: 54% score (81 killed).
  PADRAO DE REFERENCIA para futuras PRs.
- PR #102 (i18n, SUPERSEDED por #103): ZERO testes. Substituida pela #103.

### Padrao Gate Feature (EULA, Consentimento, etc)

Para features que bloqueiam o app ate acao do usuario:

### 1. Composable (src/shared/composables/)
- localStorage flag com versionamento (`eula_accepted_v1`)
- Mudar a versao invalida o flag anterior (re-exibe dialog)
- ref reativo + `accept()` / `decline()`

### 2. Componente Dialog (src/shared/components/)
- GlassCard do design-system + Vuetify components importados explicitamente
- useI18n para textos

PREFERENCIA DE UX (licencas/termos legais): O usuario quer o TEXTO COMPLETO do documento dentro do modal com barra de rolagem -- NUNCA linkar para GitHub ou docs externas. Usuario explicitamente rejeitou a abordagem de "ver EULA completo no GitHub" porque nem todo usuario familiarizado com GitHub. O texto deve ser lido sem sair do app.

Para importar texto longo de arquivos sem duplicar no componente, usar Vite `?raw`:
```ts
import eulaText from '../../../docs/LEGAL/eula/pt-BR.txt?raw'
```
O `/// <reference types="vite/client" />` em env.d.ts ja cobre a tipagem. O `?raw` injeta o conteudo do arquivo como string no bundle.

Estrutura do modal com scroll:
- Container flex column com `max-height: 90vh`
- Area de texto: `flex: 1; overflow-y: auto; max-height: 40vh`
- Hint animado "role para baixo" que some ao chegar no fundo (scroll listener)
- Botao de aceite `:disabled="!hasScrolledToBottom"` -- so habilita apos usuario rolar o texto ate o fim. Decisao explicita do usuario. Scroll listener calcula `scrollHeight - scrollTop - clientHeight < 4`.

PITFALL (PR body): NUNCA referenciar PRs de OUTROS repositorios no body do PR sem contexto explicativo. Referencia cruzada entre PR #83 (repo Electron) e PR #92 (repo web) sem explicacao confundiu o usuario. Se for referenciar, explicar o relacionamento explicitamente ou omitir.

### 3. Integracao no App.vue
```vue
<EulaDialog v-if="!isAccepted" />
<RouterView v-else />
```

PADRAO CRITICO: `v-if` no dialog, `v-else` no RouterView. NAO usar `v-show` no RouterView — v-show mantem o componente no DOM com `display:none`, o que significa que TODA a aplicacao (rotas, stores, watchers, intervalos, requests de rede) inicializa por baixo do dialog ANTES do usuario aceitar o EULA. Isso e problema de privacidade e performance. Com `v-if/v-else`, o RouterView so e criado apos aceite, garantindo zero side-effects antes do consentimento.

PITFALL (QA encontrado e corrigido): Se voce usar `v-show`, o app faz requests de API, carrega stores e dispara timers enquanto o EULA ainda nao foi aceito. O usuario pode ate ver traffic de rede acontecendo sem ter consentido. SEMPRE usar `v-if/v-else` para gates legais.

### 6. Decline Flow — Web vs Electron (PREFERENCIA DO USUARIO)

PREFERENCIA DO USUARIO (PR #91, 08/08/2026): Recusar EULA NAO deve ter confirmacao dupla.
O usuario disse explicitamente que a camada dupla ficou "excessiva". Recusar ja e uma
escolha clara — tratar como acao destrutiva com double-confirm e irritante.

#### Web (piano-web): tela de saida sem double-confirm

Para gates legais (EULA, termos), o botao "Recusar" deve:

1. NAO ser no-op (dialog fica preso na tela sem saida)
2. Mostrar tela de saida ("voce nao aceitou, feche esta pagina") — NAO usar window.confirm()
3. NAO abrir um segundo dialog de "tem certeza?" — ir direto pra tela de saida

Estrutura do componente:
- 2 estados com `v-if/v-else`: dialog principal > tela de saida
- `isExited` ref controla a tela de saida
- NAO usar `showConfirm` / dialog de "tem certeza?" (removido por ser excessivo)

Locale keys necessarias:
```ts
eula: {
  exitMessage: 'Voce nao aceitou os termos do EULA. O aplicativo nao pode ser utilizado.',
}
```

### Personalização do Palco (StageSettings) — feat/stage-customization

Modelo com MESMAS chaves JSON do APK (`bg`/`fg`/`size`/`weight`/`tsOn`...),
persistência por escopo em `user_data` (`stage.settings.<scope>`), herança
ALL-OR-NOTHING (override inteiro > global inteiro > defaults — NUNCA merge
campo a campo; `patch` em módulo herdando copia o global inteiro). Runtime
`stage-settings-runtime.ts` para popups de projeção sem pinia (localStorage
direto + BroadcastChannel `louvorja-stage-settings` + storage listener).
Testes: mockar `@shared/services/user-preferences` (NÃO o serviço de stage —
mock de módulo inteiro des-sincroniza da API real); `setActivePinia
(createPinia())` no beforeEach; jsdom manual via globalThis quando o serviço
precisa de window/localStorage. Detalhes + pitfalls de teste:
`references/stage-settings-customization.md`.

**Backgrounds oficiais (galeria DINÂMICA):** assets do casting DLNA do APK
(`~/Piano-Louvor-JA-flutter/src/assets/backgrounds/bg-*.png`) em
`src/assets/backgrounds/` (NÃO em `public/` — Vite avisa que glob em `/public/`
com `?url` é errado; em src/assets ganham hash de build e entram no precache do
PWA); lista via `import.meta.glob('../../../assets/backgrounds/bg-*.png')` —
caminho RELATIVO ao arquivo TS (de `src/modules/settings/types/` são 3 níveis
`../` até `src/assets/`; glob com nível errado retorna lista VAZIA silenciosa).
Novo asset entra sozinho (build-time: exige rebuild/dev restart). Storage no
`bgImg` com prefixo `official:bg-03` (vs `data:` do usuário);
`officialBgUrl(id)` resolve pelo próprio mapa do glob (fallback
`/backgrounds/<id>.png`); parse aceita `official:*` E `data:*` (rejeita o
resto). TODO ponto de render usa `resolveBackgroundImage()`, nunca o valor
cru. Escopos: descobertos dinamicamente (ver abaixo). Detalhes + pitfalls:
`references/stage-settings-customization.md`.

**PITFALL PWA em dev: `devOptions.enabled: true` faz o workbox interceptar os
módulos do Vite.** Sintomas: centenas de "Precaching did not find a match"
para URLs de dev (`/@vite/client`, `/src/*.ts?t=...`), "No route found", e o
SW serve código STALE do cache — erros de ReferenceError de código já corrigido
(usuário vê bug fantasma pós-fix). Correção: `devOptions: { enabled: false }`
no VitePWA — SW só em produção. Após desabilitar, o SW antigo fica registrado
nos browsers: desregistrar 1x (DevTools → Application → Service Workers).

**PITFALL regex do glob de bgs:** capturar o id COMPLETO no regex
(`(bg-[\w-]+)\.png`), não só o sufixo numérico — capturar só `01` monta URL
`/backgrounds/01.png` → 404 e a galeria inteira fica com imagem quebrada
SILENCIOSA (sem erro no console, `naturalWidth === 0`). Validar galeria com
`img.complete && img.naturalWidth > 0` no DOM, não só contar tiles.

**Escopos de módulo DINÂMICOS (2026-08-24):** `STAGE_MODULE_SCOPES` derivado
de `import.meta.glob('/src/modules/*/views/*ProjectionView.vue')` — convenção
`XptoProjectionView` → scope `xpto` (exceções: Media→hymns,
LiturgyWeb→liturgy). Módulo novo com view de projeção entra SOZINHO nas abas
do Personalizar Palco; só adicionar label `settings.stage.scope.<id>` no
locale. O descobrimento achou clock/countdown que ninguém tinha mapeado.
Store hydrata iterando a lista; runtime valida escopo contra ela. O enum
`StageModule` do APK é FIXO (hymns|bible|liturgy|timer) — não conhece
random/clock/countdown; sync .louvorja desses escopos será rejeitado até o
APK aceitar. `StageModuleScope` virou tipo derivado da lista (não union
hardcoded).

**PITFALL alinhamento no preview:** containerStyle do StagePreview precisa
mapear BOTH `alignItems` (vertical) E `justifyContent` (horizontal a partir
do textAlign) — esquecer o justifyContent deixa o texto sempre centrado e o
CSS scoped `text-align: center` mascara (inline style no `<p>` não resolve
porque o box pai é quem posiciona). Nas views de projeção o padrão
stageAlign/contentStyle já cobre os dois.

**Padrão folha (REGRA DE DESIGN, pedido explícito 2026-08-24):** toda
caixinha de texto atrás da letra (textBox do StageSettings) usa o corte
diagonal característico do app — `border-radius: 14px 0 14px 0` (views de
projeção: `clamp(14px, 2.4vmin, 32px) 0 clamp(14px, 2.4vmin, 32px) 0`;
preview 16:9: `1.4cqw 0 1.4cqw 0`). O usuário chamou de "famigerado padrão
folha" — é identidade visual em TODA superfície de projeção, mesmo padrão do
media-projection e do AppConfirm (`1rem 0 1rem 0`). NUNCA radius uniforme
(8px/12px) em caixinha de projeção.

### PITFALL i18n: locale block no NÍVEL ERRADO do objeto = leak silencioso

Sintoma: chaves cruas (`settings.stage.title`) renderizadas no lugar do texto.
Causa raiz (session 2026-08-24): bloco de locale inserido DENTRO do namespace
errado (ex.: `stage:` dentro de `projection:` → resolve
`settings.projection.stage.*` mas o componente usa `settings.stage.*`). O
plugin i18n faz merge SHALLOW (`Object.assign`) dos locales de cada módulo —
cada arquivo exporta UM namespace top-level. Aninhar errado NÃO dá erro de
build/type-check; só leak em runtime.

ANTES de concluir que a UI "não tem" uma feature i18n, auditar: extrair todos
os `t('...')`/`labelKey` dos .vue/.ts, carregar todos os locales (strip
`export default` → require CJS em tmp), resolver cada caminho no objeto
merged. Script pronto: `scripts/i18n-key-audit.cjs`. Falsos positivos:
wildcards template-literal (`weight${w}`, `scope.${id}`) e emits `update:*`
(não são i18n — excluir do regex). Componentes shared órfãos (sem import em
lugar nenhum) têm leak latente — corrigir mesmo assim.
LIÇÃO DE PROCESS: ao mover blocos grandes em locale TS com script python,
SEMPRE revalidar sintaxe (`node -e require(...)`) e chaves vizinhas — duas
rodadas de edição quebraram vírgulas/fechamento de blocos vizinhos.

### Controle Remoto web↔APK (2026-08-23, atualizado 2026-08-24)

**Protocolo v2 — fases 1-4 do Controle Remoto Total COMPLETAS (2026-08-24):** namespaces `media/bible/timer/countdown/clock/random` no mesmo envelope Remote. PRs: app#118 + apk#42 (feat/remote-v2 em ambos, 75/75 e 777/778 testes), web commit d36a3bb (PR web NÃO aberto — branch feat/remote-control carrega features mistas). Referência operacional: `references/remote-control-total-v2.md`. Desktop: `module-handlers.ts` (registry por namespace, stores pinia INJETADOS via cast `as never` — UnwrapRef não é atribuível a RefLike, execute/snapshot, catch-all → false) roteado no `liturgy-bridge.ts` ANTES de player/liturgia; whitelist de campos v2 no `remote-server.mjs` — campos novos DEVEM ser adicionados lá, senão o renderer nunca os recebe. Fase 3: `media.open {musicId, mode}` → `openMusicPlayer` (mesmo contrato Álbuns com projeção); `player.open` v1 destravado (hymnId→musicId). APK: 5 abas (Liturgia/Hinos/Bíblia/Tempo/Mais), painel Hinos com busca debounce 400ms + modos cantado/playback/slides; `mode` do RemoteCommand é REUTILIZADO (nunca duplicar campo existente). Spec no Obsidian `LouvorJA — Controle Remoto Total v2 Spec.md`.

**PITFALLS DA VALIDAÇÃO E2E (2026-08-24, dev mode):**

**ORDEM DE VALIDAÇÃO (aprendida da forma difícil):** 1) probe WS no desktop primeiro (prova servidor+handlers via ack+state); 2) log `[remote] command <action>` no remote-server confirma o que CHEGA do device; 3) só então investigar o APK — se comandos não chegam, o problema é envio (socket/conexão/token), não handler. Probe rouba a vaga do "1 cliente só" (`remote_busy`) — fechar antes de testar no device. Command id do APK é epoch em microssegundos: decodificar revela se é da sessão atual ou antiga. Release APK NÃO loga no logcat — instrumentar device exige build debug/profile.

**PITFALL MESTRE (sessão 2026-08-24, rodada final): a whitelist do `contents.send` no `remote-server.mjs` é o PONTO ÚNICO DE FALHA SILENCIOSA.** O main reconstrói o objeto do comando campo a campo com checks `typeof` antes de repassar ao renderer — campo novo que não estiver nessa lista chega `undefined` no handler SEM ERRO NENHUM (ack true, handler roda, ação falha). Sintoma clássico: probe WS manual FUNCIONA (injeta direto no pipeline) mas o device real falha — o probe não valida o caminho do device. Checklist de campo novo no protocolo: (1) encode RemoteCommand APK → (2) whitelist contents.send no remote-server.mjs → (3) handler module-handlers.ts → (4) snapshot de volta. Quando "servidor funciona mas device não" após 2+ hipóteses descartadas: parar de hipotetizar e instrumentar em CAMADAS — RAW payload no server (`JSON.stringify(msg)`), entrada do handler com `typeof msg.campo`, resultado do handler, state→APK. Dossiê: `references/remote-v2-layered-debugging.md`.

0. **Pinia setup-store DESBEMBALHA refs na instância** (fix f39d770): `store.runtime.value` é `undefined` na instância pinia — o valor é `store.runtime.status` direto. Todos os snapshots v2 liam undefined e caíam no fallback: APK via estado morto (idle/0/vazio) mesmo com ack ok:true. Fix: helper `readField(obj, key)` tolerando `Ref {value}` OU valor plano. TESTE OBRIGATÓRIO: integração com store pinia REAL (`setActivePinia(createPinia())` + `useTimerStore()`), não mock com `{value:...}` — mock esconde esse bug. Comando remoto também precisa ser AÇÃO VISÍVEL: `timer.start`/`countdown.start` também `toggleProjection()` se não projetado (senão operador acha que não funcionou). Flutter: **TabBar SEM TabController → tela cinza** (lança no build); usar `SingleTickerProviderStateMixin` + controller, IndexedStack lê `_tabCtrl.index`.
0a. **APK `send()` descartava comando silenciosamente** quando `!isConnected` (socket meia-boca pós-Android Doze ou restart do servidor): botões pause/reset "não faziam nada" sem erro nenhum. Fix: `send()` espera reconexão até 2s (10x200ms) antes de desistir. REGRA: comando de operador nunca é descartado no vácuo.
0b. **Progressão de tempo exige push periódico**: state só ia após comandos → cronômetro rodando mostrava tempo congelado no APK. Ticker de 1s no bridge empurra state enquanto timer/countdown `running` ou `finished`.
1. **Snapshot v2 no boot DEVE ser defensivo** (optional chaining + defaults). Store pinia não-hidratado estourava `Cannot read properties of null (reading 'value')` no `buildState` inicial e matava o `pushState` INTEIRO — APK em loading eterno na liturgia. Um throw em buildState derruba TODO o estado, não só o módulo novo (fix ccc987b).
2. **Sockets CLOSE-WAIT zumbis no WS :7071** (electron morto sem close) ocupam a vaga do "1 cliente" e bloqueiam conexão nova SEM erro visível — probe conecta TCP mas handshake nunca completa. Restart limpo do electron resolve.
3. **Token muda a cada restart** — extrair via `grep -ao 'token [A-F0-9]*' /tmp/piano-electron.log` (electron com stdout redirecionado; console.info não chega em terminal background). APK com token velho reconecta em loop `bad_token` — após CADA restart do electron, reler o token e reconectar o device.
4. **Dev mode desacoplado**: vite e electron são processos separados. Se o vite cair, o renderer quebra e o estado WS para. Subir vite PRIMEIRO, electron depois.
5. **APK instalado pode ser antigo** — antes de debugar "não funciona", conferir `adb shell dumpsys package <pkg> | grep lastUpdateTime` vs timestamp do build. APK v2 precisa rebuild+install após cada fase.
6. **E2E probe WS** = validação mais rápida: conectar com token → `state` (keys: liturgy,player,bible,timer,countdown,clock,random) → enviar command → `ack ok:true`. Script `.mjs` com `import pkg from 'ws'; const {WebSocket} = pkg` (ws é CJS). Cuidado com race: o PRIMEIRO state pós-conexão é o de boot (pré-comando) — esperar o ack e coletar ≥2 states.
7. **HMR não recarrega bridge instalado no main.ts**: `installRemoteLiturgyBridge` roda uma vez no boot — mudanças em liturgy-bridge/module-handlers exigem restart do electron; HMR engana (estado velho persiste).

Arquitetura validada: APK serve WS embutido (`startWebLink`), mostra 1 QR; web escaneia com webcam ou cola 1 linha de URL. Rota `/settings/remote` decide a view via `isElectronShell()`. NÃO criar item na dock. QR do offer fica visível DURANTE o scan (pitfall de v-if por step). Detalhes completos + pitfalls (ICE gathering flutter_webrtc, apostrofo em locale, scanner unificado por prefixo, qr_flutter API): ver `references/remote-control-pairing.md`.

#### Scanner QR no navegador — regra de implementação

- Scanner pertence ao repo `Piano-Louvor-JA/web`, em `/settings/remote`; o Vite do repo Electron não substitui essa tela.
- Preferir `BarcodeDetector` nativo junto de `getUserMedia({ video: { facingMode: { ideal: 'environment' } } })`; não instalar dependência se o navegador já cobre QR.
- Ao decodificar URL `ws://IP:porta?t=TOKEN`: parar interval de leitura e todas as tracks do `MediaStream`, preencher o valor e chamar `connect()` automaticamente.
- `onUnmounted` também deve parar câmera/timer. Scanner precisa manter input manual como fallback; se `BarcodeDetector` não existir, informar isso sem esconder a conexão manual.
- Há DOIS QR com propósitos distintos: QR Desktop (APK lê endpoint Electron `:7071`) e QR Web Link (navegador lê QR servido pelo APK). Rotular os dois explicitamente; nunca duplicar scanners ambíguos no APK.

#### Validação remota: não encerrar por unit test

Para controle remoto multi-repo, testes de parser/handler não comprovam operação. Antes de dizer funcional:
1. Confirmar APK recém-instalado (`dumpsys package` / timestamp) e token atual após qualquer restart do Electron.
2. Testar WS real: estado inicial, `ack` do comando e estado pós-comando. O primeiro `state` pode preceder o comando; aguardar ack e próximo state.
3. Confirmar efeito visual no alvo (timer/countdown iniciado remotamente deve abrir projeção) e atualização periódica de estado para contadores.
4. Para catálogo de hinos e Bíblia, validar dados no catálogo do DESKTOP; API pública e SQLite local podem ter IDs diferentes. Busca remota deve retornar IDs do alvo, e catálogo da Bíblia deve hidratar sem exigir que usuário abra a tela local antes.

#### Fechamento de projeção de mídia — PEDIDO DO USUÁRIO PENDENTE

O Rafael pediu explicitamente (2026-08-24, AINDA NÃO IMPLEMENTADO): fechar a
janela de projeção deve (1) pedir confirmação via AppConfirm (evitar fechamento
acidental) e (2) PARAR a música — hoje o áudio continua tocando em segundo
plano após a janela fechar. Ao implementar: interceptar close da janela de
projeção (web-projection.mjs) → confirmar → closeWebProjectionWindows() +
encerrar player/áudio. Registrar na spec do Obsidian ao concluir.

#### Fechamento de projeção de mídia

Fechar janela de projeção é ação destrutiva: confirmar pelo `AppConfirm` do styleguide; na confirmação, fechar projeção e encerrar áudio/player. Não deixar música em segundo plano após a tela visual sumir.

**REGRA (fix 2026-08-24, commit b5eeb86 apk): UI do APK NUNCA decide "conectado" por
`mode == RemoteMode.desktop`** — no Web Link o mode é `web`, o que fazia a tool page
mostrar "conecte primeiro" e o espelho de liturgia (`_isMirroring`) nunca renderizar,
mesmo com o browser conectado. Usar SEMPRE o getter canônico
`RemoteSession.isControlling` (`mode != idle && status == connected`): no modo web só
vira true quando o browser realmente conectou no WS (status `listening` ≠ conectado).
O `_emitStatus()` helper intercepta os `_statusCtrl.add` mantendo `_lastStatus` sync.
Pitfall de teste: assinar o stream `status` ANTES do `WebSocket.connect` (broadcast
perde frames de listeners tardios). Detalhes: `references/remote-control-pairing.md`.

**Fix final da validação (2026-08-24, commit 0849bf3 desktop) — pinia desembrulha refs
EM QUALQUER acesso a store injetado, não só snapshots:** `executeBible` acessava
`bible.books.value.find()` → TypeError → `bible.open` NUNCA projetava (WS CLOSE 1005,
sem close frame) e o `catch` do `searchMusic` engolia o erro da busca de hinos.
TODOS os accessos passam por `readField(store,'campo')`. E ids de catálogo: `pt_musics`
da API pública TEM os mesmos ids do SQLite local (fetch na 1ª busca ~2s, sem cache
local); `pt_hymnal` da API tem ids PRÓPRIOS (id 1728 = hino 1) — nunca usar pra
media.open; busca remota = `media.search` no índice do desktop, hits em
`media.searchResults`. Dossiê completo com ordem de validação (probe WS → grep
`[remote] command` → só então APK): `references/remote-control-total-v2.md`.

**Última rodada da validação (commits da7bc8f desktop + a486506 apk):**

- **bible.open aborta silencioso sem seleção**: `openProjection` exige
  `selectedVerses.length > 0`. Comando sem `verse` deixava seleção vazia → nada
  projetava com ack do handler rodando. Fix: **versículo default 1** sempre +
  `waitForVerse` (polling 100ms até o versículo existir em `verses`, máx 5s) —
  `refreshChapter()` é async; `selectVerse` antes dele terminar deixa seleção vazia.
- **media.open remoto SEMPRE `project: true`**: `openMusicPlayer` puro só projeta
  em `no_audio` — hino aberto pelo controle "toca mas não projeta". O bridge do
  desktop envolve a chamada (`openMusicPlayerRemote`) forçando projeção: comando
  de operador é clique esperando VER na tela.
- **Busca "não filtra" = lista congelada de query antiga**: snapshot `media`
  carrega `query` + `searchResults`; o painel do APK SÓ exibe a lista se a query
  do snapshot casar com o texto atual do input, e só reenvia busca quando o texto
  REAL muda (`_lastQuery`, debounce 400ms). Sem isso, resultados da penúltima
  digitação ficam na tela parecendo filtro morto.
- **Sorteio/Bíblia/Countdown (UX final)**: random ganha "Gerar números 1–100"
  (setMode numbers + range), projetar/parar, cancelar; countdown ganha editar
  duração (min:seg) + projetar/parar por card; bíblia rejeitou painel numérico —
  select versão + livro por NOME + chevrons, catálogo (books/versions) no snapshot
  `bible` com `bootstrap()` no boot do bridge.
- Watch patterns de background process dão falso alarme com o ruído
  `[ERROR]: gitstatus failed` do zsh — confirmar com `ss -tln`/`pgrep` antes de reagir.

**CAUSA RAIZ FINAL da validação (commit aa56431 apk): `DesktopConnection.send()`
dropava TODOS os campos v2.** Ao injetar o token reconstruía o `RemoteCommand`
copiando só campos v1 — `bible.open`/`media.search` chegavam
`{"action":...,"token":...}` PELADOS no servidor. Fix: `RemoteCommand.token`
NÃO é final — injetar in-place (`command.token = _token`), NUNCA reconstruir
comando ao adicionar campo. Probes WS nunca reproduzem esse bug (mandam token
direto no JSON) — validar comando de UI SEMPRE com o app real conectado.
Diagnóstico que fechou: log do JSON cru no server (`JSON.stringify(msg)` ANTES
da whitelist).

**Paridade do Web Link (web `96222a6` + `0a66259`):** web é ALVO do APK, não segunda ferramenta de operador. `RemoteControlView.vue` deve usar o mesmo `module-handlers.ts` do desktop, com `media.search` por `loadAlbumMusicIndex` e `media.open` forçando `project:true`. Validar `vue-tsc --build` + testes remote antes de dizer paridade. Se usuário pedir "web igual app", confirmar se quer web como alvo (fluxo padrão) ou uma segunda UI controladora — são features diferentes.

**Painel Sorteio remoto completo (espelho do desktop, mesma rodada):** modos
números/nomes (segmented), intervalo min/max + aplicar, importar nomes
multi-linha, display atual em destaque, sortear/parar, projetar/parar,
sorteados com DEVOLVER. Ações novas `random.setNumberRange/importNames/
removeDrawn`; snapshot com `available[]`, `drawn[]` (reversa), `numberMin/Max`,
`currentDisplay`. Campos novos na whitelist: `numberMin, numberMax, namesText`.
UX híbrida validada: capítulo/versículo = dropdown + chevrons no MESMO campo
(`_ChevronField`). Web tem módulos v2 no bridge mas NÃO é controlador — UI de
controle é só do APK; web controlar = feature nova (não confundir).

Dossiê completo dos 4 root causes + técnicas de diagnóstico da sessão:
`references/remote-v2-implementation-pitfalls.md`.

**Repos locais:** APK = `~/Piano-Louvor-JA-flutter/src` → `Piano-Louvor-JA/apk`;
`Piano-Louvor-JA/web` NÃO está clonado no home — clonar via `gh repo clone Piano-Louvor-JA/web`
(feature remote na branch `feat/remote-control`, módulo `src/modules/remote`).

### Autoclose de mídia projetada (REGRA de UX)

Toda mídia com "fim" natural (áudio, vídeo, YouTube, Vimeo) DEVE fechar a projeção sozinha ao terminar; mídia sem fim (imagens, PDF, slides) não. Detalhes: `references/remote-control-pairing.md`.

**PITFALL CRÍTICO — autoclose de vídeo NÃO está na branch do repo web (verificado 2026-08-24):**

Estado real por plataforma:

- **Desktop Electron** (branch `feat/remote-control-receiver` do Piano-Louvor-JA/app):
  OK. `1875405` — vídeo local `ended` e YouTube ENDED via IPC `projection:video-ended`;
  áudio já fechava; 3 unit tests em `electron/__tests__/video-autoclose.test.mjs`.
  SOBREVIVEU ao revert `884774f` (que só derrubou o espelho web-via-APK daquele repo).
- **Web** (branch `feat/remote-control` de Piano-Louvor-JA/web): **NÃO IMPLEMENTADO**.
  O commit `7a06335` (vídeo local + autoclose) foi feito num clone de trabalho e o
  commit seguinte `68414f8` ("porta liturgia Delphi") removeu o
  `liturgy-local-video.ts` junto com o port. Confirmado na branch: sem arquivo, sem
  `kind: 'local-video'`, sem `@ended` na `LiturgyWebProjectionView`; YouTube
  `onStateChange` só sincroniza play/pause (não trata ENDED state 0); Vimeo sem
  listener de `finish`. Áudio OK (`media-audio.ts` onEnded). Fontes recuperáveis:
  `git show 7a06335` no repo app.

LIÇÕES: (1) commits em clones /tmp só existem quando pushed pra branch certa —
antes de marcar "implementado" em skill/spec, conferir `git log` da branch real do
repo; (2) ao portar módulos grandes, NUNCA fazer `rm` de arquivos de features
anteriores no mesmo commit do port.

### PITFALL: Apostrofo em locale EN quebra o build

String single-quoted com `phone's` → PARSE_ERROR no Vite (en.ts:119). Locale com apóstrofo → aspas duplas. Rodar vue-tsc/build após editar qualquer locale.

### PITFALL: repo Piano-Louvor-JA/web (v1.18) é a base web NOVA

Mesma stack do app (Vue 3 + Vuetify 4 + Vite) mas módulos independentes. ANTES de criar feature web do zero, verificar se já existe em `Piano-Louvor-JA/web` — não recriar módulos que a base nova já tem.

### PITFALL: convenções de ferramentas ficam velhas — conferir package.json antes de rodar

A convenção "Biome enforced pelo CI" NÃO vale mais no web v1.20.0 (sem biome em deps/scripts/binary). Antes de rodar qualquer ferramenta citada aqui, `grep` o package.json do repo — o repo avança, a skill descreve uma data. Igualmente: `npm run vitest` não existe (usar `./node_modules/.bin/vitest` ou `npm test`).

### Playlists UI: picker é overlay PRÓPRIO no app, hub tem checklist de paridade (port 2026-08-31)

**Picker "Adicionar à playlist"**: o app usa overlay custom (`position:fixed; inset:0; backdrop-filter:blur(4px)`) + `.playlist-picker__panel` (corte diagonal, sombra 0 24px 64px), fechando em `@click.self` e ESC — NÃO v-dialog. A implementação web com `v-dialog`/`v-card` degradou pra texto cru (usuário: "esse feedback tá meio porco"). Portar o template do app 1:1, incluindo `.playlist-picker__add` (ícone "+" deslizante no hover).

**Hub (AlbumsView)**: botões-ícone (ti-upload/ti-download) ao lado do Criar; ícone de playlist em quadrado 2.2rem com fundo `color-mix(primary 18%)` (ti-music-off se vazia); chevron à DIREITA que fica primary quando aberto; play/lixeira quadrados 2.1rem (lixeira → #ff6b6b hover); tracks com índice tabular primary; feedback de import inline no card (não toast Teleport); TransitionGroup `playlist-card`.

**Dois `</style>` órfãos no MESMO dia** (AlbumsView + AlbumCollectionView): substituição de bloco CSS via script deixou o fechamento no meio do arquivo — build e testes passam, UI renderiza sem estilo. Check obrigatório pós-edição: `grep -c '</style>'` (=1) + é a última linha + `getComputedStyle(el).display` de um elemento-chave (default block/inline = CSS não aplicado).

**Dev server stale esconde mudanças de branch**: o túnel serviu v1.19.0 (staging) depois do checkout da feature — `vite` captura `define`/config no BOOT. Check: `__APP_VERSION__` no console vs package.json; divergiu = reiniciar server.

**Validação visual: vite do app no browser ≠ Electron real** (usuário corrigiu explicitamente). Usar Electron + CDP: build `--base=./`, launch `env -u ELECTRON_RUN_AS_NODE node_modules/.bin/electron . --remote-debugging-port=9222 '--remote-allow-origins=*'` (aspas obrigatórias no zsh), python websocket-client → Runtime.evaluate (router.push por NAME) + Page.captureScreenshot. Porta CDP pode pertencer a outro processo (9223 = figma-mcp) — verificar dono antes. Receita completa: `references/web-parity-f1-2026-08-31.md`.

### PITFALLS TDD em testes de componente web (pagos 2026-08-31)

1. **jsdom `window.close()` destrói o document** — testes seguintes falham com `Cannot read properties of undefined (reading 'createElement')`. Stub: `vi.stubGlobal('close', vi.fn())`.
2. **Handle de teste: anexar em `ref.value`**, nunca na Ref — anexar na Ref vira no-op silencioso no consumo via `.value` (falha como "0 calls" sem pista).
3. **Port de service puro do app**: sempre teste de roundtrip + não-compartilhamento de referência (`not.toBe`) — pega shallow copy latente do app (caso real: `serializePlaylists` com `items` vazando por referência).
4. **Teleport to="body"**: `wrapper.text()` não vê — usar `document.body.textContent` (e voltar pra `wrapper.text()` se o Teleport for removido).
5. **`vitest.config.ts` separado deve espelhar TODOS os aliases do vite.config.ts** + `globals: true, environment: 'jsdom'` — faltou no web e 14 testes quebrados no baseline (já documentado acima, reincidente).

### Auto-scroll confinado ao contêiner — NUNCA scrollIntoView para auto-follow (fix bug Ronaldo Lyma, 2026-08-31)

`Element.scrollIntoView({ behavior: 'smooth' })` num item de lista lateral rola TODOS os ancestrais scrolláveis, não só o painel — desloca palco/player/página e enfileira animações que competem com o avanço rápido de slides. Bug reportado por tester (Ronaldo Lyma) no player do app; o mesmo código existia no web.

**Padrão correto** (`media-aside-scroll.ts`, portado pros 2 repos): calcular o scrollTop do item relativo ao CONTÊINER e chamar `container.scrollTo({ top, behavior: 'auto' })`:

```ts
const top = Math.max(0, aside.scrollTop + itemBox.top - asideBox.top - (aside.clientHeight - itemBox.height) / 2)
aside.scrollTo({ top, behavior: 'auto' })  // sem smooth: evidência imediata, sem fila de animações
```

Teste unitário da função pura (`revealItemScrollTop`) + regra: só o aside rola; scroll imediato (smooth acumula com trocas consecutivas de slide). PRs app#145 / web#128.

### Web comanda TVs: web = controle, desktop = sender (arquitetura aprovada pelo Rafael, 2026-08-31)

### DESTINOS DE PROJEÇÃO (regras duras aprendidas no WT-5, noite 01/09 — consolidadas na sessão final2):

**Padrões universais desta feature (reincidentes — regra de ouro):**
- **Fix de padrão em múltiplos stores = grepar TODO `src/modules/*/stores`** (clock escapou do fix de toggle e o Rafael pegou o mesmo bug nele).
- **Runtime builder não sabe de destino**: `active` = sessão viva; parar é EXCLUSIVIDADE do clearProjection com idle explícito (condicionar active a flag de rota matou a rota mirror — regressão b7b4e44).
- **Toggle decide por estado (`isProjecting`), nunca por `isPopupModuleOpen`** — rota 'tv' não tem popup e o clique reprojetava em vez de parar.
- **Dois sistemas de nomes (moduleId vs scope) exigem tradução centralizada em UM lugar** (stageStyle no bridge: media→hymns) — consultas com o nome errado caem em defaults silenciosamente.
- Popup (BroadcastChannel) e TV (relay cloud) são canais INDEPENDENTES — nenhum
  estado de um deve apagar o outro.
- **"Fechar popup" ≠ "parar de projetar na TV"**: todo caminho que encerra
  projeção publica idle EXPLÍCITO pro relay (senão o runtime republica o
  conteúdo — hino/sorteio ficavam presos na TV com o botão desligado).
- **Rota 'Só TV (nuvem)'** (`getPopupRoute(mod) === 'tv'`): popup não abre e
  popup-fechado NÃO é "parado" — qualquer `if (!isPopupModuleOpen(mod))
  { isProjecting = false }` e qualquer toggle condicionado a popup existente
  QUEBRAM nessa rota (botão "liga 1s e volta", clique reprojetar em vez de
  parar). Toggle por `isProjecting` puro; watch de 400ms trata rota tv como
  projetando. Auditoria: grepar `isPopupModuleOpen` nos stores.
- **TV cloud conectada = sempre ativa** — sem botão play/stop (herança do
  modelo de slots do desktop; sem estado real por trás vira bug de UX).
- Bridge↔relay compartilham o socket via `window.__palcoRelaySend` / `__palcoRelayAudio` (singleton
  global escrito pelo dono da conexão no onopen) — NUNCA import entre eles (Vite cria
  múltiplas instâncias de módulo com HMR/code-splitting e o import pega
  instância com ws=null). Verificado 4x nesta feature — import estático NÃO resolve.
- **Paridade visual popup↔TV (regra do Rafael: "a projeção do operador deve ser
  idêntica ao que vai ser projetado em telas")**: toda projection carrega os
  StageSettings efetivos do módulo; fonte px@1920 com divisor **19.2** no receiver
  (10.8 = fonte 78% maior); BG: bg custom > capa do hino > backgroundColor do palco
  > fallback só p/ MP3; isCover = título como conteúdo grande. Auditoria obrigatória
  antes de fechar: comparar campo a campo o RENDER da view de projeção (popup) vs o
  envelope que o bridge serializa. Detalhe:
  `references/wt5-session-2026-09-01-final4.md` e `-final5.md`.
- **Nomes de campo entre web e receiver DIVERGEM** (web `footerRefColor` vs
  receiver `m.footerColor`; web px@1920 vs receiver vw) — SEMPRE conferir o lado
  consumidor (receiver.html/desktop painter) antes de assumir o nome/escala do
  campo; mismatch é falha silenciosa (campo ignorado, sem erro). Derivar fatores
  de escala do MESMO viewport-width de referência que a view usa (1920), não de
  resoluções "de TV" presumidas (1080).
- **moduleIds vs scopes do StageSettings são sistemas de nomes diferentes**:
  tradução (media→hymns) centralizada em UM lugar (stageStyle do bridge);
  consultas com o nome errado caem nos defaults SILENCIOSAMENTE (personalizações
  ignoradas sem erro nenhum).
- **Auditar paridade antes de documentar**: comparar campo a campo o que a view de
  projeção renderiza (popup) vs o que o bridge serializa — pegou isCover e a
  hierarquia de bg que o wire inicial errou. Na rodada 6 pegou de novo: bg oficial
  viajava como path `/src/assets/...` do bundle do OPERADOR (TV em `file://` não
  carrega → fallback preto) e a fonte quebrava em 3 linhas vs 2 (geometria do
  receiver ≠ popup). Fixes: `resolveTvBackground` (data URL self-contained —
  payload que cruza dispositivo NUNCA leva path do bundle; `toReceiverMessage`
  async, send dentro de IIFE), geometria casada (padding 3vh/4vw, max-width 92vw,
  line-height 1.25) + **AUTO-FIT no receiver** (reduz fonte ×0.94 até caber em
  76vh — "2 linhas no popup = 2 na TV", regra do Rafael). Rodada 6:
  `references/wt5-session-2026-09-01-final6.md`.

Pedido: "o web controla TVs similar ao que já se faz no app, projetando em monitores E televisores". Fronteira física: browser não abre porta → TV SEMPRE conecta no sender WS/HTTP (:7080/:7081, +2 por slot) hospedado no **Electron main**; o web comanda via `WebRemoteBridge.sendCommand('palco.*')` (remote v1 → remote-server do Electron, namespace já existe). Monitores = popups do browser (F3 da SPEC, BroadcastChannel). Fases WT-1 (status) → WT-2 (comandos + roteamento por módulo) → WT-3 (áudio TV↔local sem eco) → WT-4 (= F3). Spec no Obsidian: `04-Projects/PIANO Web - TVs e Monitores (Palco no web).md`. Detalhes de protocolo: skill `palco-multi-screen`.

### Bug report de usuário externo (tester): pipeline padrão (caso Ronaldo Lyma, 2026-08-31)

Fluxo validado: (1) evidência em vídeo MP4 > 8MB → extrair frames com `ffmpeg -vf "fps=1/3,scale=1100:-1"` e analisar frames-chave por visão (a ferramenta de vídeo tem limite de 8MB — registrar a falha na spec); (2) diagnóstico final vem do **código + git blame**, não do vídeo (frames podem não capturar o momento da quebra — dizer isso honestamente ao usuário); (3) fix em TDD nas duas plataformas (app + web) em branches paralelas `fix/<nome>`; (4) PRs separadas por repo + issue com label `bug` creditando o repórter como tester (não inventar cargo dev); (5) spec no Obsidian com causa/fix/evidência; (6) creditar sem expor: "Reportado por Ronaldo Lyma (tester)" no PR body e issue.

### Paridade web↔app — workflow obrigatório

Para "deixar web equiparado ao app" ou qualquer port app→web: (1) baseline audit cross-repo com diff de views/rotas/components/services — técnica batched + gap matrix auditada em `references/web-app-parity-gap-matrix-2026-08.md`; (2) SEMPRE clarificar escopo antes da SPEC — desktop-only (monitores físicos, FTP/Classo, sync) não portam 1:1; adaptação típica no web: "tela" = popup window (`popup-windows.ts`), bridge = BroadcastChannel (nunca WS de TV); (3) specs SDD em `.planning/` (gitignored). Gaps confirmados 2026-08-31: ESC c/ confirmação, playlist-io (import/export), autoclose vídeo/yt/vimeo, pairing views remote, palco multi-tela adaptado.

### Receiver cloud — referência consolidada (04/09/2026)

Para fluxo de receiver cloud, destino Monitor (não TV), API pública, rota `/palco/`, presença WS, cache PWA e paridade Bíblia/popup, consultar `references/cloud-receiver-flow-and-parity.md` antes de alterar `ScreensCard`, relay ou receiver.

### Fullscreen de projeção no Chrome: kiosk receiver, não popup (2026-09-03)

Atualização 04/09: fluxo completo de kiosk/click-to-fullscreen, port literal do Arranjo de Monitores, invalidação de SW do receiver e exclusão central do Monitor do operador: `references/wt5k-monitor-fullscreen-operator.md`.

`window.open(..., 'fullscreen=yes')` não remove chrome. `requestFullscreen()` em PopupHost ou no `about:blank` filho falha porque Chrome não transfere user activation. F11 manual não valida automação.

#### Receiver browser servido pela API — rota, túnel e paridade (04/09)

- Túnel do Vite/web e túnel da API são origens distintas. Nunca entregar `https://<web-tunnel>/palco/?code=...`: o SPA pode capturar `/palco/`, redirecionar à home e descartar `?code`. Receiver usa origem pública da API.
- Em Hono, registrar `/palco/` explicitamente; `/palco` + `/palco/*` pode não cobrir a barra final. Validar `GET <api>/palco/` = 200 após build/restart.
- Centralizar URL: `VITE_PALCO_API_URL=https://<api-tunnel>`; query `palcoApi`/localStorage são overrides explícitos. `ScreensCard` copia `${apiOrigin}/palco/?code=...`, nunca `window.location.origin` quando web e API divergem.
- PWA fullscreen só vale instalada/aberta pelo ícone ou kiosk. Aba comum não inicia fullscreen automático; Chromium exige gesto. Informar o limite, não prometer auto-fullscreen.
- Receiver browser em PC é `Monitor N`, não TV. Modelar receiver cloud e TV física como destinos distintos: receiver fica em `Monitores receiver`; TV física/bridge fica em `TVs do Palco`. Não reutilizar ícone, texto de pareamento ou contagem de TV.
- Browser do operador não descobre o display de outra máquina/PWA. Quando o usuário quer associação visual, oferecer select persistido `receiverId → WebScreen.id`; associação automática futura exige o receiver reportar identidade do display.
- Rota `tv`/receiver não chama popup: publica relay e mantém `isProjecting`; toggle usa estado, não `isPopupModuleOpen`, e parar manda `idle`.
- WS não prova paridade visual. Receiver deve aplicar envelope: `fontSize` px@1920 via divisor 19.2, `textColor` da Bíblia, peso, sombra, caixa folha, alinhamentos, background, `footerRefColor`/peso. Comparar visualmente receiver e popup antes de aceite.
- **Presença receiver:** aba/PWA fechada deve sair da lista em segundos. No receiver, chamar `ws.close(1000, 'receiver_closed')` em `pagehide`; no relay, `onClose → leaveRoom → notifyPresence`. Preserve o código salvo para reabrir depois, mas não mantenha uma aba fechada como monitor ativo.
- **Cache PWA:** cache-first com nome imutável serve HTML antigo após deploy e simula regressão visual. A cada mudança do shell, incremente `CACHE`; em `activate`, delete caches diferentes do atual antes de `clients.claim()`. Valide o `sw.js` pelo túnel e faça um reload forçado uma vez.
- **Capitalização Bíblia:** `textTransform` é exclusivo do texto do versículo. Referência/footer é elemento irmão e mantém case/cor/peso próprios. Se screenshot divergir, primeiro confirme cache ativo e `textColor` no envelope real; não inferir pelo HTML fonte.

**Não apontar kiosk para `/popup`:** o `--user-data-dir` isolado necessário para kiosk separa `localStorage`/`BroadcastChannel`; popup do operador ficará preta. Kiosk deve abrir um **receiver conectado ao relay** (browser/webOS/Tizen), cuja sessão/código recebe runtime independente do perfil. Só então há fullscreen real sem barras e conteúdo real.

PWA `display: standalone` serve a janela do operador; não torna popups fullscreen. Referência operacional e E2E: `references/projection-kiosk-relay.md`. Detalhe atualizado do receiver/kiosk, reconexão global e túnel Web+API: `references/wt5g-receiver-kiosk-relay.md`.

### Multi-monitor no web: iniciar permissão antes de abrir popup (2026-08-31)

Quando popups web precisam reabrir/adaptar no monitor salvo, a referência é `references/web-multimonitor-popup-layout.md`.

Regra crítica: iniciar `requestWindowManagementPermission()` **sem `await` antes** de `window.open`; guardar a Promise e reaplicar bounds quando resolver. `await` antes de `window.open` aciona popup blocker; solicitar depois de abrir pode perder a ativação do usuário e deixar a permissão em `prompt`, degradando silenciosamente para uma tela. Criar/regredir teste de ordem em `popup-windows-permission.test.ts`; validar fisicamente com dois monitores.

### ESC fecha TODAS as projeções — padrão agregador (implementado 2026-08-31)

Paridade app (ESC + confirm): no web os 7 módulos que projetam (media, bíblia, liturgia, timer, countdown, clock, random) têm métodos de fechamento DIFERENTES (`clearProjection`; bíblia usa `clearProjectionWindow`; liturgia usa `clearWebProjection` que também limpa runtime + popups + refs). O composable `useOperatorEscapeToCloseAllProjections` (src/shared/composables) coleta os closers ATIVOS (`isProjecting` de cada store + refs `siteProjectionItemId`/`videoProjectionItemId` da liturgia), abre UM `appConfirm` e fecha todos se confirmado. Guards obrigatórios (mesmos do app): ESC dentro de input/textarea/contenteditable ignorado; `document.querySelector('[role="dialog"]')` aberto → não empilhar confirm sobre confirm; flag `handling` anti-reentrada. Integração: uma linha no `AppShell.vue` (envolve todas as rotas do operador). Divergência consciente vs Electron: no app o ESC na JANELA DE PROJEÇÃO também encaminha via IPC; no web não dá pra capturar teclado de popup `window.open` de forma confiável entre browsers — ESC só funciona na janela do operador.

### ESC no now-playing: dois estágios sem fricção (adicionado 2026-08-31)

Na rota `/media`, o ESC NÃO deve sempre encerrar o player.

1. **Há projeção ativa:** ESC abre o `appConfirm` de encerramento e fecha somente as projeções ativas. O now-playing e o áudio permanecem.
2. **Já não há projeção:** o próximo ESC chama `useMediaStore().requestClose()` — reaproveita o diálogo existente do player. Após confirmação, `close()` encerra áudio/sessão e o watcher de `hasSession` volta para `/albums`.
3. **Qualquer outra rota sem projeção:** no-op.

Implementar no agregador `useOperatorEscapeToCloseAllProjections`, usando `const route = useRoute()` uma única vez. Preservar os guards: input/textarea/contenteditable, dialog aberto e anti-reentrada. Testar os dois ESCs como estados separados; resetar também refs extras de mocks (ex.: `siteProjectionItemId`) no `beforeEach`, senão um teste deixa a liturgia falsamente projetando e mascara o fluxo `/media`.

**PITFALL convenções de skill desatualizadas:** a convenção "Biome enforced pelo CI" NÃO vale mais no web v1.20.0 — package.json não tem biome em deps nem script lint, e não há `node_modules/.bin/biome`. Antes de rodar qualquer ferramenta citada pela skill, `grep` o package.json do repo. Repo avança; skill descreve uma data.

### PITFALL: git fetch stale faz commits merged parecerem perdidos

Antes de declarar "commits ficaram fora de origin/main", rodar `git fetch origin main` — o diff `origin/main..HEAD` com fetch stale mostra commits que JÁ foram merged. Caso real (31/08/2026): os 3 fixes de build da PR web#124 pareciam perdidos na `feat/playlists`; estavam todos em origin/main.

### i18n
Cada modulo tambem tem `src/modules/<mod>/locales/<locale>.ts`.
O i18n plugin (`src/plugins/i18n.ts`) usa `vue-i18n` com `legacy: false`, detecta idioma
via `getUserPreference(USER_PREFERENCE_KEYS.language)` do localStorage, fallback `pt-BR`.

## i18n Multi-Idioma (Piano-Louvor-JA/app)

Implementado na PR #102. Estrutura:
- `src/plugins/i18n.ts` — createI18n com 3 locales, detectInitialLocale via localStorage
- `src/locales/{pt-BR,en,es}.ts` — locale root (geral)
- `src/modules/*/locales/{pt-BR,en,es}.ts` — locale por modulo
- `src/modules/settings/views/GeneralView.vue` — seletor de idioma (botoes pill)
- `src/shared/constants/storage-keys.ts` — `USER_PREFERENCE_KEYS.language`

LOCALE_KEY_MAP: mapeia locale vue-i18n para prefixo de API:
- `pt-BR` -> `pt_` (pt_hymnal, pt_categories, pt_hymnal_1996)
- `en` -> `en_` (en_hymnal, en_categories — verificar disponibilidade)
- `es` -> `es_` (es_hymnal com 690+ musicas, es_categories com apenas 2 categorias)

ESTADO DE IDIOMAS (atualizado 10/08/2026):
- PT-BR: ATIVO (padrao, fallback)
- ES: ATIVO
- EN: DESABILITADO temporariamente na UI. O usuario disse: "vai ser desabilitada
  a traducao em ingles por hr pq nao temos os conteudos de midia atualmente na
  nossa api". Toda a infra EN permanece (locales, testes, localeToApiPrefix) —
  apenas o seletor nao mostra a opcao EN. Reabilitar quando a API tiver conteudo EN.

PITFALL: `es_categories` tem apenas ~2 categorias vs ~5 do `pt_categories`. UX pode ficar vazia.
PITFALL: `en_hymnal` / `en_categories` precisam ser verificados na API antes de assumir que existem.

## API Language Filter (library-catalog.ts)

Arquivo: `src/modules/sync/services/library-catalog.ts`

Atualmente hardcoded com prefixo `pt_` em 3 pontos:
- Linha ~78: `readCatalogRecord<CatalogHymnalEntry[]>('pt_hymnal')`
- Linha ~94: `readCatalogRecord<CatalogHymnalEntry[]>('pt_hymnal_1996')`
- Linha ~123: `readCatalogRecord<CatalogCategory[]>('pt_categories')`

Refatoracao: usar locale detectado pelo i18n para montar o prefixo dinamicamente.
Integracao com `getUserPreference<string>(USER_PREFERENCE_KEYS.language, 'pt-BR')`.

Detalhes completos: ver `references/api-language-filter.md`.

### 5. TDD
- `beforeEach`: `localStorage.clear()`
- Cobrir: estado inicial, accept(), decline(), versionamento, persistencia

### Dialogs: SEMPRE no styleguide — NUNCA window.alert/confirm (REGRA)

O usuario corrigiu explicitamente: modais nativos do Electron (window.confirm/alert)
"nao seguem o styleguide do app". Para QUALQUER dialog de confirmacao/aviso:

- Usar `appConfirm()` (src/shared/composables/useAppConfirm.ts) — API imperativa
  `appConfirm({title, message, confirmLabel, cancelLabel, danger}): Promise<boolean>`
- Visual: AppConfirm.vue — panel #2a2a2a, border-radius `1rem 0 1rem 0` (corte
  diagonal = identidade visual do app), botoes pill, `--ds-color-primary`
- Confirms de acao destrutiva usam labels DESCRITIVOS ("Manter e adicionar novos" /
  "Sobrescrever dias"), nunca OK/Cancel genericos

### Import de dados Delphi (ver references/delphi-import-compatibility.md)

- .ja: dias [Geral] sao 1=domingo..7=sabado; `checked` e DATA (dd/mm/aaaa) — so
  done se == hoje (reset automatico na virada do dia)
- DATAPACKET XML: ARQUIVO_INFO e flag de caminho ('I'), NAO observacao; DATA pode
  ser TDateTime float
- Import em Flutter: escrita DIRETA no repository, NUNCA empilhar eventos no bloc
  (race condition corrompia dias)
- easy_localization: `tr(args:)` NAO interpola `{0}` — usar `namedArgs` + `{count}`

## Git Workflow

CRITICAL: Cada repo tem sua branch base. NAO confunda.

### Piano-Louvor-JA/app (Electron) — base: `main`
```bash
git checkout main && git pull origin main
git checkout -b feat/my-feature
gh pr create --base main
```

### Piano-Louvor-JA/web (Vue PWA) — base: `staging`
```bash
git checkout staging && git pull origin staging
git checkout -b feat/my-feature
gh pr create --base staging
```

### Branch Separada por Feature (REGRA OBRIGATORIA)

Cada feature em branch separada a partir da base atualizada. NUNCA empilhar features
numa mesma branch. Exemplo: i18n, update system, e API language filter sao 3 branches distintas.

### Stacked PRs (feature sobre feature — quando o usuário pedir integração)

QUANDO o usuário quiser duas features validadas JUNTAS ("quero ver já os dois
integrados e funcionando juntos"), criar a branch da feature nova BASEADA na
branch da feature existente (não na base padrão):

```bash
git checkout feat/feature-existente
git checkout -b feat/feature-nova
gh pr create --base feat/feature-existente --head feat/feature-nova
```

O GitHub re-parenta AUTOMÁTICO quando a PR de baixo merga (a de cima passa a
apontar para a base da de baixo). Exemplo real (2026-08-24): PR #118
(stage-customization) baseada na PR #117 (feat/remote-control) para validar
Personalizar Palco + Controle Remoto integrados.

PITFALL stash-pop entre branches: `git stash -u && git checkout <outra> &&
git stash pop` sobre arquivos que AMBAS as branches tocaram gera conflito
diff3 nos working files (não é merge commit). Locales são o caso clássico
(ambas as features adicionam blocos). Resolução: união manual dos blocos +
REVALIDAR sintaxe com `node -e "require(...)"` (o parser pega vírgula/chave
faltante que o editor de texto não mostra) + conferir que blocos da feature
de baixo (ex: `remote:`) sobreviveram — Duas rodadas de edição de locale
quebraram fechamento de blocos vizinhos; validar sempre após cada rodada.

Commits com `--no-verify` (lint-staged local pode estar quebrado):
```bash
git commit --no-verify -m "feat(scope): description"
```

### Rebase Automatico quando base avancar

QUANDO a base (main ou staging) avancar (outro dev fez merge):
1. `git fetch origin`
2. Para CADA branch de feature aberta: `git checkout <branch> && git rebase origin/main && git push -f origin <branch>`
3. Verificar CI apos rebase (`gh pr checks <N>`)
4. NAO esperar o usuario pedir — rebase automatico quando detectar mudanca

### NAO Faca Merge (REGRA ABSOLUTA)

Ezequias faz code review antes de qualquer merge. NAO usar `gh pr merge`.
Excecao: UNICAMENTE se o usuario disser explicitamente "pode mergear".

## Alias TypeScript (tsconfig.app.json)
- `@shared/*` -> `./src/shared/*`
- `@locales/*` -> `./src/locales/*`

## Tunnel para Validacao

Dev server + cloudflared para validacao manual:
```bash
# Background: dev server
npm run dev -- --host 0.0.0.0 --port 5174

# Background: tunnel
cloudflared tunnel --url http://localhost:5174 2>&1

# Extrair URL do log:
process(action='log') -> procurar "trycloudflare.com"
```

Ver `cloudflare-tunnel-testing` para troubleshooting detalhado.

## Electron EULA Gate (Piano-Louvor-JA/app)

O repo piano-app (Electron) tem o mesmo conceito de gate legal mas com arquitetura
diferente: `dialog.showMessageBoxSync` nativo, persistencia via workspace.mjs (.bin),
e decline flow com dialog duplo recursivo.

Detalhes completos (mocks, testes, diferencas web vs electron, sync de arquivos legais):
ver `references/electron-eula-gate-pattern.md`.

### PITFALL CRITICO: docs/ no .gitignore quebra o asar (CONFIRMADO EM PRODUCAO)

Os textos EULA em `docs/LEGAL/eula/` NAO entram no app.asar porque `docs/`
esta no `.gitignore` e o electron-builder respeita o .gitignore. Resultado:
ENOENT em producao, UnhandledPromiseRejection, janela nunca abre.

BUG CONFIRMADO (08/08/2026, maquina Windows do Ezequias):
```
ENOENT, docs\LEGAL\eula\pt-BR.txt not found in app.asar
    at getEulaText (electron/eula.mjs:61)
    at showEulaDialog (electron/eula.mjs:73)
    at checkEulaAcceptance (electron/eula.mjs:158)
```
O app aparecia no Gerenciador de Tarefas mas a janela nunca abria.
Diagnostico feito rodando exe com `--enable-logging=stderr` via PowerShell.

SOLUCAO: Manter os .txt em `electron/legal/eula/` (coberto por `files: ["electron/**/*"]`).
Atualizar `getEulaDir()` em `eula.mjs` para apontar para `electron/legal/eula`.
Detalhes em `references/electron-eula-gate-pattern.md`.

### Build Windows via GitHub Actions + Debug

VM ARM64 nao roda wine — build Windows e feito via GitHub Actions (`windows-latest`).
Debug de app instalado: rodar exe com `--enable-logging=stderr` via PowerShell.
Splash screen pattern: `data:` URL inline > `loadFile` (nao depende de filesystem).
Ver `references/electron-windows-build-debug.md`.

### Sistema Global de Atualizacoes (App + Web)

Spec SDD completa para banner de versao + modal + auto-download + push notifications
across plataformas. Padrao de integracao electron-updater + composable + TDD 100%:
ver `references/electron-updater-pattern.md`.

Spec SDD completa: ver `references/global-update-system-spec.md`.

### Padrao Visual: GeneralView.vue DEVE seguir o design system entre PRs

REGRA ABSOLUTA: Quando tocar `GeneralView.vue` (ou qualquer view de settings),
SEMPRE usar o mesmo padrao visual estabelecido pela PR #93:
- **GlassCard** do `@design-system/index` (NAO `<div>` plano ou `<section>`)
- Acento colorido lateral (`.general-settings__accent`)
- Icones Tabler (`ti ti-world`, `ti ti-database`, `ti ti-trash`, etc)
- Botoes customizados com `color-mix(in srgb, ...)` (NAO `<v-btn>` do Vuetify)
- SCSS scoped com variaveis `--ds-color-*`

O usuario corrigiu explicitamente (10/08/2026):
"a generalview foi tocada nos pr93 e pr102 tem q seguir o mesmo padrao visual"

Isso vale para QUALQUER secao nova de settings, nao apenas GeneralView.
Se duas PRs tocam o mesmo componente, o resultado visual deve ser identico.

### Workflow: NAO mergear sem review do Ezequias (REGRA ABSOLUTA)

O usuario corregiu o workflow EXPLICITAMENTE (08/08/2026):
"tem q parar de mergear o irmao ezequias tem q fazer review antes de mergear".

ISSO VALE PARA TODOS OS PRs em Piano-Louvor-JA/app — nao apenas hotfixes.

1. SEMPRE criar branch a partir de `main` atualizada (`git checkout main && git pull origin main`)
2. Commitar, push
3. Abrir PR com `gh pr create`
4. AGUARDAR review do @ezequiasfonseca
5. NAO usar `gh pr merge` — mesmo com CI verde, mesmo sendo hotfix critico
6. Avisar o usuario que o PR esta pronto e aguardar

Excecao: UNICAMENTE se o usuario disser explicitamente "pode mergear".

### REBASE TODOS OS PRs quando main mudar (REGRA DO EZEQUIAS)

O Ezequias corrigiu (08/08/2026): "Depois atualiza suas branch de trabalho
com a main. Como esta tendo muita alteracao, e bom agente seguir essa
pratica pra nao sumir codigo ou voltar bugs."

QUANDO a main avancar (Ezequias fez merge, novos commits):
1. `git fetch origin`
2. Para CADA branch de feature aberta:
   ```bash
   git checkout <branch>
   git rebase origin/main
   git push -f origin <branch>
   ```
3. Verificar CI apos rebase (`gh pr checks <N>`)
4. NAO esperar o usuario pedir — rebase automatico quando detectar mudanca na main

### NSIS Multi-Idioma (EULA no installer)

Para que o instalador NSIS mostre o EULA no idioma do SO do usuario:

1. Criar `build/nsis-eula.nsh` com `LicenseLangString`:
```nsis
LicenseLangString LicenseFile ${LANG_PORTUGUESEBR} "docs\LEGAL\eula\pt-BR.txt"
LicenseLangString LicenseFile ${LANG_ENGLISH} "docs\LEGAL\eula\en.txt"
LicenseLangString LicenseFile ${LANG_SPANISH} "docs\LEGAL\eula\es.txt"
```

2. No package.json:
```json
"nsis": {
  "license": "docs/LEGAL/eula/pt-BR.txt",
  "include": "build/nsis-eula.nsh",
  "installerLanguages": ["pt_BR", "en_US", "es_ES"]
}
```

O installer detecta o idioma do Windows e mostra o EULA correspondente.
O usuario tambem pode trocar idioma no dropdown do installer.

### Cross-Platform EULA Path Resolution

O `getEulaDir()` deve procurar em multiplos locais (extraResources, asar, dev):

```js
function getEulaDir() {
  const candidates = [
    process.resourcesPath ? path.join(process.resourcesPath, "eula") : null,
    path.join(app.getAppPath(), "docs", "LEGAL", "eula"),
    path.resolve(process.cwd(), "docs", "LEGAL", "eula"),
  ]
  for (const c of candidates) {
    if (!c) continue
    try { if (existsSync(path.join(c, "pt-BR.txt"))) return c } catch {}
  }
  return path.resolve(process.cwd(), "docs", "LEGAL", "eula")
}
```

macOS precisa de `extraResources` no build config:
```json
"mac": {
  "extraResources": [{ "from": "docs/LEGAL/eula/", "to": "eula/", "filter": ["*.txt"] }]
}
```

### resolveAppLocale — Deteccao de Idioma do SO

Usar `app.getLocale()` (BCP-47) com match por prefixo:
- Match exato: `pt-BR` -> `pt-BR`
- Match por prefixo: `pt-PT` -> `pt-BR`, `en-GB` -> `en`
- Case-insensitive: `PT-br` -> `pt-BR`
- Fallback: `fr-FR` -> `pt-BR`

10 testes TDD, 100% coverage em `electron/locale.mjs`.
Passar locale via query param pro renderer: `?lang=pt-BR`

### Padronizacao de Issue/PR Templates na Org

Para padronizar templates em todos os repos da org Piano-Louvor-JA:

1. Criar branch `chore/standardize-templates` a partir de main em cada repo
2. Adicionar 4 arquivos via GitHub Contents API:
   - `.github/ISSUE_TEMPLATE/bug_report.yml` (YAML form com dropdowns)
   - `.github/ISSUE_TEMPLATE/feature_request.yml`
   - `.github/ISSUE_TEMPLATE/config.yml` (`blank_issues_enabled: false`)
   - `.github/pull_request_template.md` (checklist: testes, type-check, build)
3. Abrir PR em cada repo
4. Templates em YAML (forms) sao melhores que markdown — dao dropdowns e validacao

PITFALL: `config.yml` com `blank_issues_enabled: false` FORCA o uso de templates.
Sem isso, usuarios podem abrir issues em branco sem usar nenhum template.

### PITFALL CRITICO: git reset HEAD + git checkout -- . DESTROI trabalho nao-commitado

Se voce fizer `git stash && git stash pop` para testar algo no main, e depois
fizer `git reset HEAD && git checkout -- .` para limpar staging, TODOS os arquivos
modificados (nao commitados) sao PERDIDOS PERMANENTEMENTE. O `checkout -- .`
reverte para HEAD, e se HEAD nao tem seus cambios, eles somem.

O pior: o `git commit` subsequente inclui a versao REVERTIDA (main original),
nao suas mudancas. Voce descobre so quando os testes falham com "is not a function".

**REGRA ABSOLUTA:** NUNCA faca `git checkout -- .` quando tiver trabalho nao commitado.
Para limpar staging sem perder mudancas:
```bash
git reset HEAD          # unstage mas MANTER working tree
# NUNCA: git checkout -- .  (isso destroi suas mudancas!)
git restore --staged .  # alternativa segura (so unstage)
```

Para descartar apenas arquivos nao-rastreados especificos:
```bash
git clean -f <caminho/especifico>   # NUNCA git clean -fd sem path
```

**VERIFICACAO OBRIGATORIA APOS COMMIT:** Rodar `git show HEAD:<arquivo> | grep <palavra-chave>`
para confirmar que o commit tem o conteudo esperado. Se o checkout destruiu
suas mudancas, o commit tera a versao antiga do main.

### Padrao: Locale Parity Test (i18n)

Quando implementar multi-idioma, criar um teste que valida automaticamente que
TODOS os locales tem o MESMO conjunto de chaves. Se alguem adicionar uma chave
em pt-BR e esquecer de traduzir, o teste falha.

Arquivo: `src/plugins/__tests__/locale-parity.test.ts`

Tecnica: coletar recursivamente todas as chaves (paths) de cada locale e comparar:
```ts
function collectKeys(obj: Record<string, unknown>, prefix = ''): string[] {
  const keys: string[] = []
  for (const [key, value] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${key}` : key
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      keys.push(...collectKeys(value as Record<string, unknown>, path))
    } else {
      keys.push(path)
    }
  }
  return keys.sort()
}

const ptBRKeys = collectKeys(ptBRMessages)
const enKeys = collectKeys(enMessages)

it('en tem todas as chaves que existem em pt-BR', () => {
  const missing = ptBRKeys.filter((k) => !enKeys.includes(k))
  if (missing.length > 0) console.error('Chaves faltando em EN:', missing)
  expect(missing).toEqual([])
})
```

### Padrao: Mock de @plugins/i18n em testes de modulos

O `@plugins/i18n` chama `createI18n()` como side-effect ao importar. Em testes
de modulos que importam `localeToApiPrefix` ou outras funcoes de i18n, o side-effect
pode quebrar a importacao causando `TypeError: X is not a function`.

**SOLUCAO:** Sempre mockar `@plugins/i18n` nesses testes:
```ts
vi.mock('@plugins/i18n', () => ({
  localeToApiPrefix: (locale: string) => {
    const prefix = locale.slice(0, 2).toLowerCase()
    if (prefix === 'en' || prefix === 'es') return prefix
    return 'pt'
  },
  default: {},  // createI18n default export
}))
```

### Padrao: getCurrentApiPrefix com localStorage direto

Para services que precisam do idioma atual SEM contexto Vue (library-catalog.ts, etc),
ler `localStorage` direto em vez de passar pelo composable i18n:

```ts
export function getCurrentApiPrefix(customLocale?: string): string {
  if (customLocale) return localeToApiPrefix(customLocale)
  try {
    const stored = localStorage.getItem('user_data')
    if (stored) {
      const prefs = JSON.parse(stored)
      if (typeof prefs.language === 'string') {
        return localeToApiPrefix(prefs.language)
      }
    }
  } catch {
    // localStorage indisponivel (SSR/test) — fallback pt
  }
  return 'pt'
}
```

O parametro `customLocale` permite testes deterministicos sem depender de localStorage.

### PITFALL: gh pr edit --body quebra markdown (backticks interpretados pelo shell)

NUNCA usar `gh pr edit N --body "texto com backticks"`. O shell interpreta
backticks como command substitution e `\` escapes, corrompendo o markdown.

**Sintoma:** Checkboxes perdem o `- ` prefixo (`[ ] Bug fix` em vez de
`- [ ] Bug fix`), texto entre backticks vira saida de comando, caracteres
especiais (acentos, parenteses) quebram.

**SOLUCAO:** SEMPRE usar `--body-file`:
```bash
echo "markdown content" > /tmp/pr-body.md
gh pr edit N --body-file /tmp/pr-body.md
```

Ou via execute_code com Python `write_file`:
```python
with open('/tmp/pr-body.md', 'w') as f:
    f.write(body)
gh pr edit N --body-file /tmp/pr-body.md
```

### PITFALL: Primeira checkbox de uma lista pode perder o prefixo `- `

Ao gerar PR bodies programaticamente, a primeira linha de uma secao com
checkboxes pode perder o `- ` antes do `[ ]`. O GitHub nao renderiza
`[ ] Bug fix` como checkbox — so renderiza `- [ ] Bug fix`.

**VERIFICACAO:** Apos criar/editar PR body, rodar:
```python
lines = body.split('\n')
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('[ ]') or stripped.startswith('[x]'):
        if not stripped.startswith('- ['):
            print(f"BROKEN linha {i+1}: {line}")
```

### Cross-repo issue deduplication (org Piano-Louvor-JA)

Quando a org tem multiplos repos (app, web, api, site), issues de API podem
se duplicar entre `app` e `api`. Padrao pra limpar:

1. Listar issues de API em cada repo (`gh issue list --label enhancement`)
2. Cruzar por titulo/keyword (Docker, Cloudflare, OpenAPI, SQLite, etc)
3. Fechar duplicadas no repo ERRADO (app) com comentario linkando pro repo CERTO (api)
4. `gh issue close N --comment "Duplicada -> Piano-Louvor-JA/api#M" --reason "not planned"`
5. Issues que sao projetos comerciais futuros (ex: CCB) → fechar com `--reason "not planned"`

### PITFALL CRÍTICO: dev server iniciado ANTES do checkout = túnel serve código velho (pago 2026-08-31)

O `vite dev` captura o estado do repo NO BOOT (`define` de `__APP_VERSION__`, config, módulos). Se o server subiu na `staging` e depois você faz checkout da feature branch, HMR NÃO recompila config/package.json — o túnel serve o bundle antigo indefinidamente. Sintoma: usuário vê UI "quebrada/antiga", `__APP_VERSION__` no browser diverge do `package.json` local, mudanças commitadas "não aparecem".

**REGRA:** ao trocar de branch, REINICIAR o dev server antes de qualquer validação visual. Verificação rápida via console do browser: `__APP_VERSION__` vs `grep version package.json` — divergiu = server stale.

### PITFALL CRÍTICO (variante inversa do "perder </style>"): reescrita de bloco CSS pode deixar o SCSS FORA do `</style>` (pago 2026-08-31)

Ao substituir uma seção de estilos dentro de `<style scoped>` via script/patch, o `</style>` pode acabar no MEIO do arquivo (se a âncora final não incluir o fechamento), deixando todo o CSS novo órfão DEPOIS dele. O compilador SFC ignora silenciosamente: build PASSA, testes PASSAM, e a UI renderiza sem nenhum estilo novo. Nada falha — só não aplica.

**Detecção rápida:** `getComputedStyle(el).display` de um elemento-chave no browser — se voltar `block`/`inline` default em vez do `flex`/`inline-flex` esperado, o CSS não está aplicado. **Regra:** após reescrever bloco de estilos em SFC, validar que `</style>` é a ÚLTIMA linha do arquivo (`grep -n "</style>" file.vue`) + conferir 1 computed style no browser.

### Electron preso no splash: assets relativos e CDP (04/09/2026)

Se o Electron real fica no banner de loading, confirmar o `file://` e os recursos via CDP antes de culpar Vite/web. `dist/index.html` com `/assets/*` quebra no Electron; `build-only` deve usar `vite build --base=./`. Ver `references/electron-splash-relative-assets.md`.

### Validação visual web↔app: vite do repo app NO browser ≠ Electron real

Subir `npx vite` do repo app e abrir no Chrome NÃO é "ver o app" — é o renderer sem shell (sem titlebar/zoom/atalhos, sem dados reais do workspace FTP/.sysdata, fontes/DPI divergentes). O usuário corrigiu explicitamente isso. Para paridade UI, subir o Electron de verdade com CDP:

```bash
node_modules/.bin/vite build --base=./   # SEMPRE --base=.
env -u ELECTRON_RUN_AS_NODE node_modules/.bin/electron . --class=louvorja-piano \
  --remote-debugging-port=9222 '--remote-allow-origins=*'
```

Pitfalls: (1) `--remote-allow-origins=*` SEM aspas → zsh expande o glob ("no matches found") e o electron nem inicia; (2) sem a flag, o WS do CDP rejeita com `403 Forbidden`; (3) `env -u ELECTRON_RUN_AS_NODE` obrigatório no Hermes. Script python de evaluate+screenshot: `pip install --break-system-packages websocket-client` → conectar no `webSocketDebuggerUrl` do `/json` → `Runtime.evaluate` (router.push por NAME, awaitPromise) → `Page.captureScreenshot` salva PNG real da janela. Ver `references/electron-cdp-live-validation.md` na skill `louvorja-app`.

### PITFALL: testar fix na janela ERRADA — app instalado vs instância dev (pago 2026-08-31)

O usuário testou o fix do aside e disse "não funcionou" — mas a janela aberta era o **AppImage instalado v1.22.1** (build de ontem), não a instância dev. Antes de qualquer validação manual de código novo: `pgrep -af electron` — se não houver processo do repo (`node_modules/electron/dist/electron .`), o que está na tela é o instalado.

Receita de subida da instância dev com o código novo (sem rebuild):
1. `pkill -f 'electron \.'` + remover locks stale: `rm -f ~/.config/LouvorJA-PIANO/Singleton{Lock,Cookie,Socket}` — o SingletonLock do app instalado derruba a instância dev ~10s após subir, silenciosamente.
2. **NÃO usar `loadFile(dist/)`** para validar código novo: o build usa paths absolutos `/assets/*` que em `file://` resolvem pra raiz do disco → vários `ERR_FILE_NOT_FOUND` (via CDP `Network.loadingFailed`) e janela em loading infinito.
3. Apontar pro Vite dev: `VITE_DEV_SERVER_URL=http://127.0.0.1:5199/ npx electron . --remote-debugging-port=9222` (main.mjs lê a env e faz `loadURL`; HMR aplica fixes na hora).
4. Confirmar via CDP que o fix está NA janela: `Runtime.evaluate` → `document.scripts` (hash do bundle) + grep no bundle minificado pela assinatura do fix (ex.: nova função presente, `scrollIntoView` ausente). `readyState === 'complete'` + `appHTMLLen > 0` = UI renderizada.
5. Instância dev e instalado compartilham `~/.config/LouvorJA-PIANO` — enquanto a dev roda, o instalado não abre (e vice-versa).

Detalhes: skill `palco-multi-screen` → `references/palco-desktop-sender-2026-08-25.md` (seção "Dev-run do Electron").

### Playlists UI: picker de faixa é overlay PRÓPRIO, não v-dialog (portado 2026-08-31)

O app implementa o picker "Adicionar à playlist" como overlay custom (`position:fixed; inset:0; backdrop-filter:blur(4px); background rgb(0 0 0 / .55)`) + `.playlist-picker__panel` (corte diagonal `--ds-radius-lg`, sombra `0 24px 64px`), fechando em `@click.self` e `@keydown.esc`. A primeira implementação web usou `v-dialog`/`v-card` do Vuetify — sem os styles do Vuetify aplicados degradou para texto cru no rodapé (o usuário chamou de "porco"). Porte o template do app 1:1 (incluindo `.playlist-picker__add`, o ícone "+" que desliza no hover da opção). Ainda: o SCSS do picker inteiro estava DEPOIS do `</style>` (órfão, silenciosamente ignorado) — mesmo pitfall do AlbumsView no mesmo dia. Ao editar CSS de `.vue` via script, SEMPRE verificar `grep -c '</style>'` (=1) e que é a última linha.

### Playlists UI: hub (AlbumsView) — checklist de paridade com o app

Elementos que a versão inicial web errou e o port corrigiu: botões-ícone compactos (ti-upload/ti-download) ao lado do Criar em vez de v-btn com texto; ícone de playlist em quadrado `2.2rem` com fundo `color-mix(primary 18%)` (ti-music-off quando vazia); chevron à DIREITA que fica primary quando aberto; play/lixeira como quadrados `2.1rem` com borda (lixeira → #ff6b6b no hover); tracks com índice tabular em `--ds-color-primary`; feedback de import como `<p>` inline no card (não toast Teleport); TransitionGroup `playlist-card` + Transition `playlist-tracks`. Strings hardcoded PT da view ("Playlists", "Criar", "Nenhuma playlist...") foram pra locale — novas telas já nascem i18n.

### UI parity web↔app: portar LITERAL de ~/piano-app, não re-implementar (REGRA do Rafael, 2026-08-31)

Quando o pedido for "deixar o web equiparado ao app em UI/UX", a referência é o TEMPLATE+CSS de `~/piano-app/` — ctrl+C/ctrl+V com adaptações mínimas (Electron→browser), NUNCA re-implementação com componentes Vuetify. Caso real: o picker de playlist foi re-implementado com `v-dialog`/`v-card` no web; sem os estilos do Vuetify aplicados degradou pra texto cru no rodapé, e o Rafael devolveu duas vezes ("meio q tem q ser um ctrl+C ctrl+v da ui do app", "ainda falta muito pra chegar na paridade"). O app usa overlay próprio (`position:fixed` + backdrop blur + painel com corte diagonal) — portei 1:1 e fechou.

### FAB da paleta: static em slot do pai, NUNCA fixed/Teleport global (paridade app, 2026-08-31)

O `StagePaletteButton` no app é `position: static` dentro de um wrapper posicionado pelo PAI — nunca `position: fixed` com Teleport to="body". O fixed global sobrepõe título/letra/aside (o Rafael reportou "botões fab sobrepor texto"). Mapeamento correto por view (validado em prints do app rodando, commit `c13ab6b`+`7413aeb`):

- **Central de Mídia (AlbumsView): SEM FAB** — Rafael explícito ("aqui no albums acredito q não precise"); removido em `6f2d375`.
- **Coletânea (AlbumCollectionView): coluna própria ACIMA do header** — FAB sozinho na primeira linha à esquerda, voltar+ícone+título embaixo (print do app: FAB(52,177) acima do voltar(50,235)). Negative-margin pra "subir" o header SOBRE PÕE o FAB — não usar.
- **Player (MediaView):** absolute no canto do palco (`.media-window__stage-palette`, stage com `position: relative`).
- **Bíblia:** dentro de `.bible-toolbar__actions`.
- **Liturgia/Random: inline no header** — Liturgia num `header-start` agrupando FAB+brand (slot absolute top-right SOBREPÕE o bloco "Programação/data"); Random logo após o botão voltar.
- **LiturgyView do APP** ganhou o FAB a pedido do Rafael (`feat/palette-fab-views`, FAB + PalcoRouteSelect no header) — features de UI continuam nascendo no app primeiro.

Regras duras: o componente em si é `position: static` (revert do Teleport+fixed era o diff inteiro entre repos); **o print do app rodando no usuário é a fonte da verdade visual, não o CSS do repo** (v1.22.0 instalado mostrava FAB à esquerda num CSS que dizia right); ao portar componente posicionado, fazer `diff` do arquivo entre os dois repos antes de assumir.

### Autoclose de vídeo/YouTube na projeção web — arquitetura (implementado 2026-08-31)

O player YT vive no CONTROLE (playback local); as telas são espelho mudo via BroadcastChannel sync. Portanto: vídeo local (`kind: 'video'`) — `@ended` dispara no POPUP → publica runtime DEFAULT (inativo) via `publishLiturgyWebRuntime` + `window.close()`; YouTube — ENDED (state 0) dispara no `onStateChange` do CONTROLE → `clearLiturgyWebRuntime()`. Padrão do app (commit 7a06335): revoke do blob URL + window.close() + closeProjectionModule. Composable de referência: `src/modules/liturgy/composables/useLiturgyVideoAutoclose.ts`. Vimeo fica de fora: o embed sem Player API não emite "fim" — exigiria o SDK do Vimeo (decisão separada).

### Playlists e fila de reprodução (implementado 2026-08-27, PR app#131 `feat/playlists`)

**Port web concluído (PR web#127, 2026-08-31):** fila, tocar tudo, playlists no
hub + export/import (`playlist-io.ts` com deep copy — corrigiu shallow copy
latente do app), ESC agregador com confirmação, autoclose vídeo/YouTube.
Detalhe: `references/web-parity-f1-2026-08-31.md`.

Decisões de escopo do Rafael + arquitetura (media-queue.ts puro, store reativo,
playlist-storage localStorage, UI picker/toast/acordeão), pitfalls de PR
empilhada e branch restack com subagent. Detalhe completo:
`references/playlists-feature.md`.

- "Tocar tudo" SOMENTE dentro da coletânea; sem botão por categoria/global
  (Rafael pediu remoção explícita do botão de categoria).
- Hinários (`kind==='hymnal'`) nunca ganham auto-play; faixa individual entra
  em playlist manual.
- Picker de faixa SÓ adiciona a playlists EXISTENTES; criar é só no hub —
  Rafael julgou criação no picker desnecessária.
- Feedback de adição = TOAST fixo no rodapé (✓ + "‘Faixa’ adicionada a
  ‘Playlist’", some em ~2,6s); duplicata consecutiva gera toast "já está" —
  nunca silêncio (`addPlaylistItem` retorna `{playlist, added}`).
- Hub: playlist acordeão com faixas visíveis e remoção individual (X);
  remover playlist = lixeira com aria-label nominal.
- Fila visível no player: painel troca para "Fila de reprodução" quando
  `queue.length > 1`; clicar numa faixa = `jumpToQueue(index)`.
- Governança: feature sugerida por usuário externo (@educharquero) → PR
  própria (base `feat/multi-output`, empilhada) referenciando e citando o
  autor como reviewer; branch de multi-telas limpa de commits de playlist.
- **Música avulsa zera a fila** (fix 4a3b424): `open()` limpa
  `queue/queueIndex`; `playQueueItem()` guarda e restaura após o open.
  Avulsa = painel de slides (padrão); fila > 1 = painel "Fila de reprodução".
- **ESC no player** (issue #132, sugestão do Caique): keydown global na rota
  do player → `requestClose()` (confirmação), nunca fecha direto.
- **Validar com `npm run build`, não só `vue-tsc --noEmit`**: o CI usa
  `vue-tsc --build` (project references) que pega erros a mais (tipos não
  exportados, index signature). Erros reais: `RandomRuntimeState`,
  `ProjectionInput`, `BibleProjectionRuntime`, `intent` sem `clock`.
- **CI não roda em PR empilhada** (trigger só staging/main) — validar branch
  de baixo com cherry-pick dos fixes.
