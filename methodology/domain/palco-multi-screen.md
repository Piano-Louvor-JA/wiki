# Palco Multi-Screen

> **Metodologia pública** — arquitetura multi-tela e cast para TV. Aplica-se a qualquer stack.

---
Sistema de projeção em N TVs a partir de um celular: espelhado ou com
conteúdo independente por tela (telão=hino, lateral=liturgia, hall=avisos).

## Arquitetura (validada em teste real com 2 simulators)

```
StageSession (facade — 29 callers usam project()/playHymnAudio()/startTimer())
  └── roteia via _projectionTargets() / _audioTarget()
        └── PalcoOrchestrator (singleton)
              └── Map<String, PalcoSlot>
                    └── PalcoSlot = PalcoController próprio + portas próprias
                          slot 0: HTTP 7080 / WS 7081
                          slot 1: HTTP 7082 / WS 7083  (+2 por slot, max 4)
```

## Regras de roteamento (CRÍTICO — todo conteúdo novo deve seguir)

- **TODO runtime de módulo projetável precisa de flag `projecting` (INTENÇÃO)
  separada de conteúdo, publicada em TODA transição liga/desliga** — três bugs
  reais 27/08 da mesma família (desktop): bíblia mantida na TV com projeção
  DELA desligada (caminhos de desligar fora do clear não publicavam off →
  restore eterno); sorteio congelado a cada novo número (`startDraw` recriava
  runtime SEM spread e derrubava a flag); countdown de sessão morta roubando
  o owner no boot (projetava 00:00 nas TVs). Regras: normalize legacy
  `source.projecting === true` (ausência = false, NUNCA default true);
  replace de runtime em store SEMPRE `...runtime.value`; guard anti-stale
  na hidratação (`runtimeIsFresh` — segmentStartedAt >12h = não confiável).
- **Não chamar `stage.palco` diretamente em UI de módulo.** Timer, áudio,
  vídeo, slides e limpar devem passar por métodos de `StageSession` que usam
  `_projectionTargets()` / `_audioTarget()`. Chamadas diretas só atingem
  Principal e criam o bug "funciona na TV 1, não na TV 2".
- **Minimizar NowPlaying não é stop.** `dispose()` de NowPlaying não pode
  chamar `stopHymnAudio()`. X/stop explícito para; minimizar mantém áudio e
  projeção.
- **Mini-player precisa guardar contexto completo da faixa.** Guardar
  `Hymn detail`, `audioSource`, `audioIsLocal`, `instrumental` e cover no
  notifier; ao tocar no mini, reabrir `NowPlayingPage` diretamente, não
  navegar para a aba Hinos.
- **`nowPlaying.start` deve gravar o detail COMPLETO (`getHymnDetails`),**
  nunca o `hymn` do catálogo — hymn de lista não tem `lyricRaw`, e o
  reabrir pelo mini fica sem letra/capa com fundo preto (bug real
  2026-08-21, corrigido nos 2 fluxos do AlbumDetailPage).
- **Stop/X de áudio para TODOS os slots conectados** (`stopHymnAudio` /
  `pauseHymnAudio` iteram `_allConnectedControllers()`), não só o ativo —
  a faixa pode ter começado noutro slot antes da troca de chip. Receiver:
  `audio stop` volta pro idle (stop = parada real; minimizar não envia stop).
- **X do NowPlaying = stop + fechar a página** (chamar `_stopAudioEverywhere()`
  e depois `Navigator.maybePop()`); ⤢ = minimizar sem parar nada.
- **Timer/áudio têm semântica diferente:** timer e texto podem ir a vários
  targets; áudio deve ir a uma TV só para evitar eco.

- **Texto/projeção/timer/vídeo/slides PPTX**: `_projectionTargets()` —
  grupo espelho OU slot ativo. Fallback: `_palco` (principal).
- **Áudio**: `_audioTarget()` = primeiro target — SEMPRE 1 TV só (eco).
  serveMedia de arquivo local DEVE usar o mesmo controller do playAudio
  (URL de mídia é por sender/porta — usar controller errado = TV não acha).
- **Sincronização de estado**: PalcoSlot faz
  `controller.addListener(notifyListeners)` no construtor — sem isso o
  Gerenciador de Telas só atualiza fechando/abrindo (bug real 2026-08-21).
- **Slot extra precisa do sender LIGADO ao ser adicionado**
  (`addSlotOnline`) — sender desligado = "desconectado" eterno.

## Persistência de configuração

- Salvar IDs/labels de slots, porta derivada e slot ativo em
  `SharedPreferences`; restaurar com `loadStoredConfig()` antes de ligar o
  palco.
- Ao restaurar, subir senders dos slots extras (`startStoredSenders`) para
  que TVs reconectem sem recriar configuração.
- `PalcoController.isRunning` é diferente de `isConnected`: sender pode estar
  ouvindo porta enquanto nenhum receiver está conectado.
- Persistência deve ser não-bloqueante (`unawaited(_persistConfig())`) e
  remover slot também deve persistir.

## Receiver (TV webOS / web)

- **Browser/PWA independente (WT-5J)**: detalhes em `references/browser-pwa-receiver-2026-09-04.md`. O receiver browser é servido pela API em `/palco/*`, usa `display: fullscreen`, persiste o código e reconecta via WS da mesma origem. O PIANO Web copia `https://<api>/palco/?code=<6 chars>` pelo botão **Adicionar receiver**. Não tratar monitor físico como popup: cada monitor/TV é um receiver real. Fullscreen/posição inicial ainda exigem instalação/ação do SO; popup `window.open`, `requestFullscreen` em filha e `chrome --kiosk` no perfil aberto não são soluções confiáveis.

- **App .ipk empacotado pode bloquear `fetch http://` pra LAN** (visto no
  webOS TV Simulator 26) — scan e IP manual falham juntos, browser da TV
  funciona. Entrada manual e host salvo devem conectar **WS direto** (WS não
  sofre CORS). Detalhe + fix: `references/palco-desktop-sender-2026-08-25.md`.
- **Simulator 26 carrega apps por DIRETÓRIO** (`appEntries` no json de
  config, auto-reload ON) — atualizar = git checkout no repo local +
  reabrir app; ares-install/porta 6622 não funcionam nele.
- **Receiver tem 3 cópias a sincronizar** em toda mudança: repo
  palco-receiver (PR, main protegida), `electron/palco/` do desktop
  (embutido :7080), `~/palco-receiver/webos` (simulador).
- **TODO conteúdo http que o receiver consome (bg, capa, áudio do catálogo)
  passa pelo `proxyUrl()` → `http://sender:7080/proxy?url=`** — o sender
  PRECISA ter /proxy implementado de verdade (não só no comentário) e TODO
  caminho local (assets do build) virar URL absoluta do sender. Sintoma de
  falta disso: "letras vão, bg e áudio não" (2ª rodada de fixes 2026-08-25).
- Porta aceita via query `?port=7083` e **persistida** em
  `localStorage.palcoPort`; HTTP probe derivado: `httpPortFor(ws) = ws-1`.
- Tecla vermelha (403): entrada aceita `IP` ou `IP:PORTA`.
  - `:` entra via `e.key` (layout-proof p/ Electron/Chromium ABNT),
    fallback keyCode 186/59. Limite 21 chars.
  - `;` é convertido pra `:` (shift não reportado em alguns layouts).
- Cada receiver guarda SEU host/porta — mesma TV reconecta no mesmo slot.

## Controle remoto desktop (APK ↔ Electron)

Sessão dedicada em `references/remote-control-desktop-bridge.md` — servidor
WS :7071 no main, bridge renderer, QR pairing, liturgia espelhada. Pontos
críticos cobertos lá (resumo):

- **Cast do DESKTOP pra TV também existe (desde 2026-08-25)**: o Electron tem
  seu próprio sender Palco multi-SLOT (:7080/:7081 slot 0, :7082/:7083 slot 1,
  +2 por slot) — ver `references/palco-desktop-sender-2026-08-25.md` e
  `references/palco-desktop-multislot-2026-08-25.md`. O remote :7071 ganhou o
  namespace `palco.*` para o web/APK ligarem o cast do desktop à distância.
- **Desktop tem roteamento por MÓDULO** (`palco-routing.ts`): cada módulo
  (bible/hymns/liturgy/random/clock/timer/countdown) escolhe 'mirror' ou um
  slotId, persistido em localStorage. `palcoSession.projectRouted()` resolve
  o alvo. Áudio continua com ALVO ÚNICO (paridade APK — sem eco).
- **Takeover híbrido por slot (desktop, 27/08, commit a183ef1)**: desde a
  feat/multi-output a decisão do que cada slot mostra é função PURA
  (`output-plan.ts` → `planForSlot`) aplicada pelo `renderAllSlots()` da
  bridge — precedência: TAKEOVER (owner com rota pro slot toma a tela) >
  RESTORE (slot atribuído com runtime vivo mostra conteúdo ATUAL do módulo
  atribuído, nunca congela) > ESPELHO legado (SÓ com owner em mirror —
  owner com rota individual NÃO vaza pros espelhos) > IDLE degradado. Zero
  passo manual (regra o PO: "0 atrito"). Módulo com intent vivo reassume
  palco órfão (early-return do setIntent claima quando `wants && owner===null`).
  Detalhe: skill `Piano-Louvor-JA-palco-cast`
  → `references/session-2026-08-27-takeover-hibrido-telas.md`.

- **Vídeo da liturgia ≠ player de hinos**: comandos `player.*` do controle
  remoto devem rotear via `resolveMediaTarget()` para a PROJEÇÃO
  (`projection.remote*`) quando `getPlaybackState()` retorna estado — senão
  controles/slider de volume não afetam o vídeo (bug real 2026-08-22, fix
  ea82a11 no branch `feat/remote-control-receiver` do Piano-Louvor-JA/app).
- **UI de Settings no web DEVE portar o CSS literal do card desktop
  equivalente do `<clone local do app>/`** (correção do o PO, 3x na sessão 31/08 —
  "esteticamente e em funcionalidade ta diferente"). Regra: reutilizar as
  MESMAS classes CSS e estrutura DOM (`palco-slots-card`, `palco-slot`,
  `palco-slot--active`, `palco-slot__dot--on`, `palco-slot__badge`,
  `__power`, `__remove`, `__add`) e os mesmos elementos funcionais — dot
  verde reflete popup/receiver VIVO real (popup-refs), play abre/fecha de
  verdade (`openPopupModule`/`closeScreenPopups`), "+ Adicionar Tela" e
  lixeira como no "Adicionar TV" (via `setPopupCount`). Card só-visual foi
  rejeitado. Em dúvida, medir `getComputedStyle` do app via CDP e copiar os
  valores. Feature autônoma (popups do navegador) no TOPO como protagonista,
  ZERO menção a desktop/dependência; integração dependente (TVs via
  desktop) colapsada/abaixo como opcional.
- **UI de Settings no web DEVE espelhar o vocabulário e os componentes do
  card desktop equivalente** (correção do o PO, 2x na sessão 31/08: "não
  ta nem parecido e ainda menciona que tem dependência do desktop").
  Regras: portar header com ícone em caixinha + título + subtítulo, lista
  com dot de status, nomes "Tela principal"/"Tela {n}", hint "Nos módulos,
  escolha Espelhar (todas) ou uma tela individual"; e ZERO menção a
  desktop/dependência em feature autônoma — "conecte o desktop" só no
  contexto onde a conexão é real (Controle Remoto). Feature autônoma no TOPO
  como protagonista; integração dependente colapsada/abaixo como opcional.
- **Console do main Electron é invisível** em `electron:dev` (chromium
  redireciona stdout pra socket) — debugar com `fs.appendFileSync`.
- Branch desktop com trabalho real: push no MESMO dia (ver
  `git-disaster-recovery` para replay do session DB se perder).

## Pitfalls (não regredir)

1. **webOS TV Simulator (Electron) no Linux**: SEM SSH (ares-install não
   funciona), drag&drop de IPK NÃO funciona no Linux. Testar multi-tela
   com 2 instâncias exige `--user-data-dir` ISOLADO por instância —
   senão compartilham localStorage e as duas "TVs" conectam no MESMO slot.
2. **Editor de arquivos Dart neste repo**: `patch` falha com CRLF;
   sed/python podem corromper `;`. Sempre validar com `dart analyze`
   (LSP dá diagnósticos STALE — analyzer real manda). Após editar,
   `dart format` + `flutter analyze` antes de build.
3. **write_file com disco cheio** cria caminho aninhado duplicado
   (`src/home/...`) e arquivo vazio — checar `df -h` antes de escrever.
4. **Disco**: `flutter build apk` + gradle caches + test_cache lotam 120G.
   Limpar: `rm -rf build ~/.gradle/caches ~/.dartServer ~/.pub-cache`
   (recupera ~10G). Não tocar: .nvm, .rustup, chrome profile.
5. **PalcoSlot settings**: `StageSettingsRepository` só aceita scopes
   fixos (global/hymns/bible/liturgy/timer) — assertion error se passar
   id do slot. Slots usam 'global' por enquanto.
6. **Testes quebram se `_audioTarget()` roda com palco desligado**
   (`_palco!` null) — chamar DEPOIS do check `_routesToTv`.

## Estado (2026-08-21)

- APK 0.1.86: versículo, timer, áudio, vídeo, PPTX roteando por slot;
  minimizar/reabrir NowPlaying com capa+letra; X para tudo e fecha;
  persistência de telas/slot ativo; espelho com UI compacta.
- IPK receiver 0.1.20: porta persistente + `:` no input + splash full-bleed
  + stop volta ao idle + paridade androidtv.
- PR apk #38 (staging) e PR palco-receiver #1 abertos.
- CI agora roda em PRs pra staging; rulesets exigem ADMIN pra ativar
  status checks (pendente usuário). Ver pitfalls: parte 2.
- Issue aberta: áudio para na TV após minutos (debug via logcat).

## Separação de repos web vs app (correção do o PO, 2026-08-24)

O "modo web" do controle remoto (Web Link: APK serve WS, browser conecta)
vive no repo **`Piano-Louvor-JA/web`**, NÃO no build browser do
`Piano-Louvor-JA/app`. Erro real: bridge browser commitada no repo app
(`e5865b8`) → revert `884774f` → portada ao web (`8ab514e`), com paridade
obrigatória das funcionalidades browser-safe (import .ja, agendados,
AppConfirm, idiomas). Sempre confirmar o repo-alvo antes de codar feature
"web". Detalhe completo: skill `Piano-Louvor-JA-flutter` →
`references/piano-web-remote-control.md`.

## Estado final do WT-4 (31/08/2026, commits b9ed925/2b269b4/5af9013 + 336ecde/e987931)

- **Wire do roteamento FEITO**: `openPopupModule` (popup-windows.ts) consulta
  `getPopupRoute` quando moduleId é roteável e sem slots override — rota
  individual abre popup dedicada só no slot designado (`?module=&slot=`).
  Teste em popup-windows-permission.test.ts.
- **Roteamento módulo a módulo** nos headers de 7 módulos (PopupRouteSelect
  compact; Bible via BibleToolbar) — removido do card de telas (o PO: no
  app é configurado módulo a módulo, igual PalcoRouteSelect do desktop).
- **Card Telas do Palco**: "+ Adicionar Tela"/lixeira (setPopupCount, clamp
  1..6), dot verde = popup viva real (getPopupRefs polled), play/stop por
  slot (toggleSlot → openPopupModule/closeScreenPopups).
- **Fix bug Ronaldo Lyma** (PRs app#145, web#128): `scrollIntoView` no aside
  do player rolava ancestrais e quebrava layout — substituído por
  `media-aside-scroll.ts` (scrollTo calculado, behavior auto, só o painel).

## Pitfalls (adicionais, sessão 31/08)

9. **Timers reais pendentes entre testes**: `scheduleSync` agenda setTimeout
   250/800/1500ms; teste A deixa refs e os timers disparam durante o teste B
   re-adicionando refs — `beforeEach` limpar `mocks.refs` NÃO basta. Sintoma:
   teste passa isolado, falha na suite. Fix: limpar refs dentro do teste
   dependente ou fake timers.
10. **Electron dev**: subir com `VITE_DEV_SERVER_URL=http://127.0.0.1:5199/`
    no env (carregar `dist/` por file:// quebra assets absolutos → load
    infinito). Remover `~/.config/LouvorJA-PIANO/Singleton*` antes (lock do
    app instalado mata a instância dev silenciosamente).
11. **Screenshot de página do Electron via CDP**: Page.enable +
    Emulation.setDeviceMetricsOverride (ex.: 1400x2400) +
    Page.captureScreenshot; filtrar `/json/list` por `type=='page'` e URL —
    o DevTools aberto vira outra entry e o índice 0 pode ser o devtools.
12. **`window.open` em jsdom lança "not implemented"** — em testes de
    popup, mockar com objetos completos (closed, close, name, focus,
    postMessage, __popupSlot) e limpar refs DENTRO do teste dependente.

## WT-3 parcial — web comanda TVs reais + WT-5 independência (01-09)

- Seção "TVs do Palco" no `ScreensCard.vue` web: Adicionar/Remover/Play/
  Ligar TV via remote `palco.slot-add/remove/start/stop` (app branch
  `feat/remote-palco-slots` 4148061). Popup NÃO é TV — conceitos separados
  nos cards (correção o PO: "popup nenhuma conecta numa TV").
- **WT-5 ESPECIFICADO (01-09)**: web sem desktop via relay WS na API
  própria (`/v1/palco/relay/:code`) — web e TV ambos clientes da API,
  código curto 6 chars (evolução do rendezvous remote_sessions).
  Desktop local continua em paralelo. Fases 5a API → 5b receiver browser
  → 5c web+QR → 5d Tizen/webOS/AndroidTV. Spec completa no Obsidian
  `04-Projects/PIANO Web - TVs e Monitores (Palco no web).md` e em
  `references/web-controls-tvs-wt3-2026-09-01.md`.
- Pitfalls novos: Electron rodando mais velho que o código (checar
  `ps -o lstart` vs commit date); Vue warn com source correto = cache
  HMR (verificar o que o SERVIDOR serve via curl antes de reescrever).

## Slots lógicos, "＋ Nova tela" e multi-monitor (2026-09-06)

Detalhe completo em `references/slots-logicos-tuneis-2026-09-06.md`. Resumo:
- **Slot é LÓGICO (janela/conexão), não monitor físico** — funciona com
  qualquer quantidade de monitores; Window Management API é ponte opcional.
- **window.open com FEATURES ('popup=yes,...') é NEGADO pelo Chromium** —
  causa real do "✕ Pop-up bloqueado" no receiver. Usar window.open sem
  features + fallback âncora target=_blank (commit 7748220).
- **Chave de slot por SESSÃO** (`louvorja.palco.slot.<code>`, só persiste
  com ?slot= da URL) — chave global fazia janelas brigarem pelo mesmo slot.
  "＋ Nova tela" abre `?code=X&slot=N+1` (cfcd765).
- **kiosk.sh --all atribui slot=N por tela** (b6d364b) — N monitores
  fullscreen zero-clique com conteúdo distinto.
- **PWA instalado não abre 2ª janela** (Chromium nega em standalone) e o
  launch perde query string — PWA = 1 aparelho/TV; kiosk.sh = N telas do
  mesmo PC. Pendente: seletor de slot no setup do receiver (mitigação PWA).
- **Web sem ?palcoApi= em prod cai em same-origin** — POST de sessão vai pro
  túnel do Vite e quebra (causa do Ezequias não criar sessão). Cura: abrir
  web com ?palcoApi= (fica no localStorage).
- **Quick tunnel trycloudflare morre com o cloudflared** — URL não volta;
  recriar e usar a nova. API viva = /v1/health 200 (não /health, que é 404).
- **Select nativo branco-no-branco**: regra global `select option, select
  optgroup` com --ds-color-* em base.css (125f578); color-scheme: dark no
  :root NÃO basta com background/color explícitos no select.
- **Kiosk browser-agnostic (0ac93e7)**: Edge > Chromium > Chrome > Brave >
  Firefox (Windows: Edge primeiro — pré-instalado); Firefox usa `-kiosk`
  sem `--app` e pode ignorar bounds; Safari não tem kiosk via CLI (caminho
  dele é o PWA). Multi-monitor por bounds garantido só na família Chromium.
  `kioskCommandFor()` no web mostra o comando certo por SO do operador.
- **Popup em produção (relato de culto 06/09)**: `translate="no"` faltava
  (Chrome Translate reescrevia hinos na tela — fixado nos 2 index.html);
  minimizar o operador mata as popups do mesmo window group (mitigação
  planejada: auto-reopen); hino nasce com tela branca/fora de sync porque
  o catálogo NÃO tem tempos de slide (lyric é string plana, slides todos
  00:00:00 — sync por tempo sem dados). Receiver /palco/ ainda não tem
  case 'audio'. Detalhe: `references/producao-kiosk-browser-agnostic-2026-09-06.md`.

## WT-5 IMPLEMENTADO (01-09) — palco cloud sem desktop: `references/wt5-cloud-relay.md`

WT-5a/5b/5c + E2E ponta a ponta PRONTOS e validados (E2E PASS real, não simulado).
Referência completa (contrato do relay, gotchas @hono/node-ws, onde vive cada peça,
commits/branches): **`references/wt5-cloud-relay.md`**. Resumo:
- API `piano-api` `src/v1/palco/` — relay WS fire-and-forget em memória (TTL 30min),
  código curto 6 chars + token HMAC, papéis operator/sender/receiver, endpoint
  bootstrap `GET /sessions/:code/token`. PR api#50 + branch feat/palco-token-endpoint.
- Receiver cloud `palco-receiver/browser/index.html` (feat/cloud-receiver) — digita
  código → token → WS role=receiver.
- Web `stage-relay.ts` (feat/palco-tv-control 89d8e8e, 190/190) — mesmo contrato do
  desktop session; card TVs com modo cloud quando desktop offline.
- E2E: `node scripts/wt5-e2e.mjs` (piano-api) — sessão → TV bootstrap → broadcast
  bíblia → late-join → idle, tudo SEM desktop. WT-5d ✅ (ver seção abaixo na referência).
- **Fluxo streaming (decisão FINAL o PO, 01/09 noite): a TV CRIA a sessão e
  mostra o código+QR no idle; o web consome `?palco=CODE` do QR** — padrão
  YouTube/Netflix ("o QR no web tá invertido"). Web: `createSession()` manual
  ficou como fallback, QR removido do card, dep `qrcode` removida. TV: OK com
  campo vazio = criar sessão. Detalhes, gotchas (QR encoder à mão NÃO vale a
  pena — use qrcode-generator embutida e valide com jsqr; detecção de dev
  local no receiver) e commits: ver "Fluxo streaming" na referência
  `references/wt5-cloud-relay.md`.
- **WT-5 COMPLETO de ponta a ponta (01/09 noite)**: além do streaming, a
  sessão fechou reconexão por `cid` (falso positivo 4409), presença de
  receivers (`youare{receivers}` no join/leave — falso negativo "aguardando
  TV conectar") e o **wire da projeção** (`publishToStageRelay` nos runtimes
  bible/media/timer/countdown/clock — hino projetou de verdade na TV cloud,
  com late-join). Todos os detalhes, gotchas e E2E reais em
  `references/wt5-cloud-relay.md` (seções "Reconexão por cid",
  "Presença de receivers", "Wire da PROJEÇÃO").
- **Web — mudanças soltas pendentes viram buraco na PR**: na sessão 01/09 o
  `desktop-palco-session.ts` tinha 29 linhas não commitadas (createTv/removeTv/startTv/
  stopTv) que eram a metade que faltava do contrato `StageBridge` (o relay cloud já
  tinha os métodos). Checar `git status -s` de TODOS os repos WT antes de abrir PR —
  mudança "solta" geralmente é trabalho perdido do ciclo anterior, não lixo.
- **REFINAMENTOS FINAIS (01/09 noite)**: causa raiz do publish mudo (Vite duplica
  módulo com `?t=` do HMR → fix `window.__palcoRelaySend` registry), roteamento
  "Só TV (nuvem)" por módulo, card lista só TVs realmente conectadas
  (receiverList), paridade visual popup↔TV (bridge anexa StageSettings),
  persistência da sessão do operator no reload. Detalhes, gotchas e checklist
  de regressão: `references/wt5-cloud-final-2026-09-01.md`.
- **Smoke tests podem quebrar ANTES de você tocar**: o smoke do browser receiver já
  estava vermelho no branch (esperava template literal `` `/sessions/${code}/token` ``
  mas o HTML usava concatenação). Rodar os smokes ANTES de implementar — corrigir o
  código pro contrato que o teste espera (o teste é o spec).
- **Mock `mockImplementationOnce` encadeado no fetch**: cada `Once` é consumido
  por UMA chamada em ordem — mapear as calls (POST /sessions → Once#1, GET
  token → Once#2). E `code.value` só é setado no `onopen` do WS: no teste,
  chamar `FakeWebSocket.instances[0].serverOpen()` antes de assertar
  `connected`/`code`.
- **webOS TV Simulator 26 (AppImage Electron) em dev**: o app Palco carregado
  nele é cópia antiga — WT-5d cloud NÃO existe na build carregada. Atualizar
  via menu File do simulador apontando pra pasta `~/palco-receiver/webos/`
  (não IPK; ares-install/6622 não funcionam — ver pitfalls #1). Alternativa
  via botão Inspect: `location.href='file://.../webos/index.html?api=ws://localhost:3100/v1/palco&code=XXXXXX'`
  (o `?code=` é boot path cloud do WT-5d). NÃO roubar foco do usuário:
  xdotool windowactivate caiu no Chrome com jogo aberto — oferecer os passos
  e deixar o usuário clicar se ele estiver usando a máquina.
- **Disco 100% trava npm/vitest** (ENOSPC): liberar ANTES de rodar testes.
  Seguro: `npm cache clean --force`, `rm -rf ~/.cache/google-chrome
  ~/.cache/node-gyp` (~750MB). NÃO apagar sem consentimento: `.ipk` velhos em
  palco-receiver, caches gradle/flutter (o PO bloqueia rm em massa).

## Web comanda TVs (WT-1/WT-2, 2026-08-31)

O web (Piano-Louvor-JA/web) controla o cast do desktop via remote `palco.*`:
`WebRemoteBridge` manda command **com token** (extraído da URL `?t=`) e
`request()` promise-based lê acks estendidos `{ok, data}` para
`palco.status`/`palco.slots` (WT-1) e liga/desliga/idle (WT-2). UI:
`PalcoTvCard.vue` em Settings→Projeção. Detalhes, gaps de protocolo e
pitfalls: `references/web-controls-tvs-2026-08-31.md`.
Fases seguintes (WT-3 áudio, WT-5 WebRTC sem desktop) na spec do Obsidian
`04-Projects/PIANO Web - TVs e Monitores (Palco no web).md`.
Fronteira física: browser não abre porta — TV real exige desktop sender rodando.
**Estado final**: WT-4 100% fechado (b9ed925) — roteamento módulo a módulo
wireado no openPopupModule; UI de telas = paridade 1:1 do PalcoSlotsCard
(Adicionar/Remover Tela, dot vivo, play/stop funcionais).

## WT-4a — módulo por popup (web 100% sem desktop, 2026-08-31)

A infra multi-tela do web já existia (popup-windows/PopupHost/popup-layout)
mas `popupModule` era UMA storage key — todas as popups espelhavam o mesmo
módulo. Fix: popup aberta com `?module=<id>` na URL vira DEDICADA (ignora
broadcast/storage do módulo global); sem query = popup espelho. Novo
`popup-routing.ts` (port do `palco-routing` do desktop): rota `mirror` |
slotId por módulo, persistida, `resolveSlotsForModule()` com fallback.
Mesma referência: `references/web-controls-tvs-2026-08-31.md`.

## Referências
- `references/receiver-parity-sync-2026-09-11.md` — paridade do receiver
  webOS==Tizen==AndroidTV (fonte única, gate de CI), recuperação da PR #11
  travada (lint de segurança com falso positivo em query string de WS,
  regex de credencial literal vs concatenação), "+ Nova tela" remove ?slot=,
  browser standalone por design.
- `references/web-controls-tvs-2026-08-31.md` — WT-1/WT-2/WT-4a completos:
  web comanda TVs (token em todo command — web sem token levava bad_token e
  desconexão; ack estendido com `data` em 3 camadas), `request()` promise-based,
  PalcoTvCard, roteamento popup por módulo (popup dedicada via `?module=`),
  Electron dev via VITE_DEV_SERVER_URL (dist sob file:// quebra com
  ERR_FILE_NOT_FOUND em /assets), SingletonLock, e correção de UI
  desambiguando "TVs (via Desktop)" vs "Telas de Projeção (popups do
  navegador)" (feedback o PO: dois cards "Telas" com conceitos diferentes =
  confuso; diferenciar no TÍTULO).
- `references/web-controls-desktop-sender-2026-08-31.md` — WT-1/WT-2/WT-4
  (2026-08-31): ack estendido {ok,data} em 3 camadas, token ?t= obrigatório
  no command (web sem token = bad_token + desconexão — testes com
  FakeWebSocket NÃO pegam isso), WT-4 popup-routing/?module= dedicada, e as
  regras de UI paridade desktop exigidas pelo o PO (2 correções na sessão).
- `references/web-link-liturgy-bridge.md` — contrato Remote v1 para bridge browser ↔ APK, diagnóstico de protocolo e TDD cross-repo.
- `references/multi-palco-pitfalls-2026-08-21.md` — sintomas, causas e correções
  para reatividade, persistência, timer/áudio, mini-player e receiver Electron.
- `references/palco-desktop-sender-2026-08-25.md` — sender do Palco no
  ELECTRON desktop (HTTP :7080 + WS :7081, protocolo v2, receiver embutido,
  namespace remote palco.*, pitfalls contextBridge/WS/sed-CRLF) e receita E2E.
- `references/palco-desktop-multislot-2026-08-25.md` — multi-SLOT no desktop
  (PalcoManager, portas +2 por slot), roteamento por MÓDULO (mirror vs slot),
  bridge de todos os módulos (owner-based), rota de áudio TV/local, e os
  pitfalls de i18n programático (anchor de bloco errado + vírgula dupla CRLF)
  e de posicionamento do FAB de paleta.
- `references/desktop-palco-state-receiver-2026-08-27.md` — invariantes
  desktop validadas: `projecting` vs conteúdo, takeover exclusivo, TV-only
  sem janela física, replay vivo, MP3 enviado nos canais video+audio e
  checklist de sync dos receivers.
