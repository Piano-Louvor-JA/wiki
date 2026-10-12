# Pianolouvorja Stage Customization

> **Metodologia pública** — personalização do Palco (StageSettings). Aplica-se a qualquer stack.

---
Domain knowledge do sistema de personalização de palco replicado web (Piano-Louvor-JA/web, PR #118) + desktop (Piano-Louvor-JA/app, PR #119, base `feat/remote-v2`). Modelo espelha o APK campo-a-campo.

## Arquitetura (as duas camadas — decisão UX 25/08/2026)

1. **`/config → Projeção & Telas → Personalizar Palco`** = source of truth. Tabs global + todos os módulos. `StageCustomizationCard` + `StagePreview` (16:9, unidades cqw).
2. **Botão de paleta em cada módulo** = atalho contextual. Abre `StageCustomizationDialog` com `only-scope` (mostra SÓ a tab daquele módulo — nunca listar todos). Dialogs legados de bgColor/textColor ficam deprecados no fluxo.

## Modelo StageSettings (v2 — sub-objetos aditivos)

- Chaves do JSON EXATAMENTE iguais ao APK: `bg, fg, size, weight, tsOn, tsBlur, tsInt, boxOn, boxBg, boxBorder, tAlign, tVAlign, refColor, refWeight, showVer, bSize, bWeight, bFg, bgImg` (+ `clock/timer/countdown/random`).
- **Herança por escopo**: `override do módulo > global > DEFAULT_STAGE_SETTINGS`. `patch()` faz merge parcial: mudar 1 campo num módulo herdando cria override a partir do global.
- **Sub-objetos por módulo ADICIONAM sem subscrever a base**:
  - `clock: { style: digital|analog, showSeconds, format24h }`
  - `timer: { timeFormat }`, `countdown: { timeFormat }`
  - `random: { fontSizePc, textTransform, animationSpeed }`
  - Sub-objeto existe SÓ no escopo do módulo correspondente.
- Escopos são DINÂMICOS: `import.meta.glob('/src/modules/*/views/*ProjectionView.vue')` (Media→hymns, LiturgyWeb→liturgy). NUNCA hardcode.
- Fundos oficiais: prefixo `official:bg-XX`, glob em `src/assets/backgrounds/` (12 PNGs). `backgroundImage: null` → cor.
- Persistência: `user_data` (localStorage) → `stage.settings.<scope>` — UMA fonte de verdade.

## Runtime (views de projeção/popups, sem pinia)

`stage-settings-runtime.ts`: `readEffectiveStageSettings(scope)` + `subscribeStageSettings(cb)` via BroadcastChannel `louvorja-stage-settings` + storage event. Store chama `notifyStageSettingsChanged()` ao persistir.

Padrão de integração em TODA view de projeção:
```
const stage = ref(readEffectiveStageSettings('<scope>'))
onMounted(() => unsubStage = subscribeStageSettings(...))
onUnmounted(() => unsubStage?.())
// stageStyle (bg+img cover/center) no ProjectionBackground
// stageAlign (justifyContent/alignItems) no container
```

**Previews (ClockPreview etc.) DEVEM ser `background: 'transparent'` SEMPRE** — se pintarem `config.bgColor` legado no modo projeção, cobrem o stage por cima (bug clássico).

`effectiveConfig = { ...configLegado, ...stage.<subobjeto> }` — migração gradual; configs legados viram fallback.

## Widgets na tela principal

O container `__preview` do widget (ClockView/TimerView/CountdownView) recebe `:style="stageBg"` + `border-radius/overflow: hidden` pra clipar dentro do GlassCard. Reativo via subscribe.

## Anatomy do grupo de tempo (padrão)

`header > content > stage > GlassCard(toolbar/preview/controls)` com widget `aspect-ratio: 21/9`, `max-height: min(100%, 28rem)`. CountdownDurationInput tem modo `compact` (HH:MM:SS overlay no topo do preview). TODA view nova do grupo segue isso.

## StagePaletteButton (FAB para módulos sem toolbar)

FAB circular fixo (Teleport to body), canto **inferior direito acima do dock** (`bottom: calc(var(--ds-dock-height, 4.5rem) + 1rem)`), abre dialog `only-scope`. Plugado em: Bible, Liturgy, Media (hymns), Random. Grupo de tempo usa a paleta na toolbar do widget.

- Posição DECIDIU-SE bottom-right (era top-right; colidia com toolbars e o seletor "Destino do palco").
- Prop `rightOffset?: number` (px) empurra o FAB quando o módulo tem botão de ação no canto (Bíblia usa `:right-offset="76"` por causa do botão Projetar 64px). Validar overlap por CDP `getBoundingClientRect()` nos DOIS botões.
- Ver Palco Cast abaixo — o seletor `PalcoRouteSelect` também vai no header de cada módulo; nunca empilhar os dois no mesmo canto.

## Palco Cast (multi-TV + áudio na TV) — paridade PalcoOrchestrator APK

Implementado no desktop (branch `feat/stage-customization`). Detalhe completo em `references/palco-cast.md`. Resumo das regras críticas:

- **Sender = main process** (`electron/palco-server.mjs`): slots independentes, slot N = portas `7080+2N`/`7081+2N`. Slot 0 ("principal") = retrocompatível. Receiver conecta por WS — SEM ping (webOS 4.x), SEM token.
- **preload expõe `window.louvorja.palco`** (contextBridge) — NÃO `window.palco`. Bug clássico: `window.palco` → undefined silencioso.
- **Projeção NÃO vai pelo WS do receiver→sender**: só renderer → `palco:send` (IPC) → broadcast. Mandar direto no WS do receiver não tem efeito.
- **BG/áudio locais não existem na TV**: `resolveBgUrl()` converte `/assets/bg-XX-hash.png` → `http://ip:7080/bg/bg-XX.png`; áudio/cover `file://`/`local://media/...` → `servePath` → `/media/`. O receiver faz `proxyUrl()` em TODO http (roda em origem local) — o `/proxy?url=` do sender DEVE existir.
- **Roteamento por módulo** (`palco-routing.ts`): `mirror` (todas TVs) ou slotId, persistido por módulo em `louvorja-palco-routing-v1`. `projectRouted(module, ...)` resolve.
- **Seletor de destino HÍBRIDO (25/08)**: `PalcoRouteSelect` lista em optgroups "Espelhar todas" + **TVs (slots com clientes)** + **Monitores/projetores** (via `listSystemDisplays`, estendidos com resolução no label). Escolher monitor → `createSlot` + `window.open(receiver do slot, monitor=<id>, fullscreen)` — monitor cabeado vira destino roteável por módulo igual TV (arquitetura híbrida: escolher conteúdo por tela mesmo sem TV). Sem TVs, monitores ainda aparecem.
- **Hinos no Palco (decisão o PO 25/08)**: título da música SÓ no slide de CAPA (`isCover`), em **Title Case** (`titleCase()` no bridge), na cor `footerRefColor` do escopo (amarelo padrão). Slides de letra FICAM LIMPOS, sem rodapé — "não precisa exibir o nome em todos os slides". Era invertido antes (título em todos exceto capa). `ProjectionInput` tem `footerColor?` opcional que sobrescreve o do escopo.
- **Áudio tem UM alvo só** (igual APK); conteúdo visual pode divergir por TV. `audioOnTv` no media store = rota TV (local silencia). Em ambiente híbrido (PC+cabo), áudio deve ir às caixas do PC; rota só-TV é para cenário sem sistema de som. Mesmo na rota TV, a letra CONTINUA projetada junto do áudio — nunca trocar a projeção pela tela now-playing.
- **Bridge INTENT-based (spec 27/08)**: claim/release só na TRANSIÇÃO do sinal de projeção (`setIntent`), nunca por mensagem de runtime; release SEM cadeia de fallback — runtime sticky (ex.: `bible.active`) NUNCA reassume sozinho, voltar exige clique Projetar. Ver references/ownership-by-intent.md. Detalhe completo do protocolo/slots em references/palco-cast.md.
- **Receiver sincronizado em 4 pontos** (regra dura): `palco-receiver/webos/`, `tizen/`, `androidtv/assets/palco/`, desktop `electron/palco/`. Esquecer um = dessincronização.
- **Fix WS direto**: app empacotado (webOS/Tizen/AndroidTV) bloqueia `fetch http://` pra LAN → scan E probe `/status` falham. IP manual conecta WS DIRETO (WS não sofre CORS); host salvo com probe falhando → `directTry()` 1x antes de descartar.

- **Recursos externos → TVs do Palco (PPTX/PDF/imagem/vídeo, 25/08)**: bridge renderer NÃO os espelha; controlar no MAIN (`web-projection.mjs`). PDF/PPTX/galeria: lê estado (`__liturgyPdf`/`__liturgyGallery`), captura slide e envia por `serveMediaBase64` + `projection` com texto vazio. Vídeo local deve preferir protocolo `video` + `servePath` (player fullscreen nativo e `ended → idle`); YouTube sem arquivo usa captura de frames, nunca prometer 30fps. Frame com URL fixa (`frame.png`) congela por cache e só muda em F5: use nome único com timestamp + retenção limitada de mídia. Para frame/slide no receiver, esconder `#veil` escuro quando `m.text` é vazio. Ao encerrar externo, remover `projection` do replay (`lastByType`), senão receiver reconectado recebe frame congelado depois de idle. Mudança no main EXIGE restart; janela/control-bar restaurada por sessão pode usar preload antigo e ficar órfã de `sourceWindow`: reload da control-bar ou sinal IPC explícito deve registrar/adotar janela antes do sync. Sempre validar replay WS: estado correto não pode ser `idle,bgPalco,projection(frame)`; projection deve variar durante captura.

## Pitfalls (registrados com custo real)

1. **Build Electron exige `vite build --base=./`** — `build-only` gera paths absolutos → ERR_FILE_NOT_FOUND → tela preta. Usar `npm run electron:preview`. **NUNCA `npm run build -- --base=./`**: o npm captura a flag (warning "Unknown cli config") e o Vite builda absoluto MESMO assim — popups novos abrem brancos/"carregando" sem erro no console, janela principal antiga sobrevive. Repassar direto ao binário: `node_modules/.bin/vite build --base=./`.
2. **Locale parity desktop**: chaves de settings vivem em `src/modules/settings/locales/` (MÓDULO), não no root `src/locales/`. No WEB, o bloco `stage` existe só em pt-BR (EN/ES ocultos — padrão do repo).
3. **Rebase pode duplicar chaves de locale** (`checkUpdate`, `changeTheme`) → TS1117 object literal. Remover as duplicatas do próprio commit, manter as do upstream.
4. **`gh pr edit --base` falha silenciosamente** (GraphQL projectCards deprecated). Usar `gh api repos/O/R/pulls/N -X PATCH -f base=<branch>`.
5. **Push após rebase**: `git push --force-with-lease`.
6. **Electron single-instance + porta CDP**: matar TODOS (`pkill -9 -f louvorja-piano`) e conferir porta 9223 livre antes de relançar com `--remote-debugging-port`.
7. **Navegação em Electron via CDP**: `location.hash` não funciona (app restaura estado). Usar `router.push({name})` via `document.querySelector('#app').__vue_app__.config.globalProperties.$router`. Ver detalhes em references/cdp-validation.md.
8. **pkill de próprio processo**: `pkill -f` que casa o próprio bash do terminal mata a sessão com -9/-15. Usar padrão mais específico (`pkill -f "piano-desktop/node_modules/.bin/electron"`).
9. **Chaves de locale em bloco errado**: inserir via anchor de chave duplicada (`desktopOnly` existe em VÁRIOS blocos) pode cair em `settings.general` em vez de `settings.palco` — sintaxe válida, testes passam, mas UI renderiza `settings.palco.tvs` crua. Ao adicionar chave, conferir EM QUAL bloco entrou (grep o bloco pai), não só se existe).
10. **Sed em arquivos CRLF**: `sed -i` sem tratar `\r` não casa fim de linha e "funciona" sem mudar nada. Em locales/repo CRLF, usar `patch` ou Python com `newline=''`.
11. **Receiver acumula classes de estado**: no handler `projection`, `box-on`/`box-off` e `shadow-on`/`shadow-off` são estados mutuamente exclusivos. Ao ativar um, remova classe oposta; ao desativar, faça o inverso. CSS com seletores de mesma especificidade pode deixar classe antiga posterior anulando o estilo atual. Validar sequência `false → true → false → true`, não apenas primeira projeção.
12. **Paridade do receiver é byte-level**: após mudar protocolo/renderização, aplicar a mesma alteração em `electron/palco/index.html`, `electron/palco/receiver.html`, `palco-receiver/webos/index.html`, `tizen/index.html` e `androidtv/assets/palco/receiver.html`; comparar SHA-256 e rodar teste estático que exige as duas remoções de classes.
13. **Visual da caixa no receiver = padrão folha do preview**: `border-radius: 2.4vh 0 2.4vh 0` (2 cantos OPOSTOS, nunca 4) e borda FINA `.1vh` (não .4vh). `palco-session.ts` envia `boxBorder: { width: 0.1 }`. Se o usuário disser "a caixa não tá igual ao preview/StagePreview", comparar border-radius e espessura de borda primeiro — o resto (bg, opacity) já vinha correto.
14. **Rota de áudio TV: PC NÃO pode tocar junto**. `useMediaStore.play()` na rota `tv` deve manter `audio.volume = 0` (só timeline avança — a TV é a caixa); sem isso o play() comum faz fade-in e o PC vira eco da TV. `setAudioRoute('tv')` já silencia, mas `play()` posterior reverte.
15. **Sync de áudio rota TV precisa propagar pause do PC**: `syncAudio` (palco-bridge) deve disparar não só na troca de faixa (URL) mas quando `media.isPlaying` muda — rastrear `lastTvPlaying`; pausa no PC → `action:'pause'` na TV; play → reenvia faixa+posição. Sem isso, pausar no PC deixa a TV tocando.
16. **Rota TV = áudio E letra JUNTOS (decisão final do usuário 25/08)**: `projectMedia` (palco-bridge) SEMPRE envia `projection` de letra, inclusive na rota `tv` — o receiver decodifica áudio independente do visual; a projeção convive com o player. Racional: ambiente híbrido (PC+cabo) o som vai pras caixas do PC (rota "só TV" não faz sentido aí); ambiente só-TV a TV é a saída E mostra a letra. NUNCA bloquear a projeção de letra pela rota de áudio.
17. **Interrupção (close) derruba tudo**: `useMediaStore.close()` já fecha projeção cabo (`clearProjection`) e zera session → watcher `hasSession` do bridge manda `audio stop` → TV idle. Requisito "close = idle em todas as telas" já coberto; validar E2E ao tocar nesse fluxo.
18. **SEEK do receiver tem AUTO-PLAY se pausado** (`if(a.paused&&target>0.2)playWithFallback()` no handler `seek` — design p/ sync do modo Ambos). Na rota tv, pausar no PC faz `currentTimeSec` ancorar/degrau >2s → watcher de seek dispara → TV RETOMA SOZINHA ("pausei e voltou a tocar"). Fix DEFINITIVO (25/08, após 2 tentativas): watcher de `currentTimeSec` (palco-bridge) IGNORA rota `tv` E o syncAudio da rota tv NÃO tem seek periódico NENHUM — no início a TV bufferiza atrasada e o seek de 3s em 3s corrige pra trás = looping no começo da faixa (reintroduziu o bug antigo do modo Ambos). Na rota tv a TV obedece SÓ play/pause/stop do operador + seek DELIBERADO (salto >5s vs `lastTvPosSec`, uma vez). Lição: NUNCA adicionar sync periódico de posição na rota tv; micro-sync contínuo é exclusivo do modo Ambos.
19. **Receiver `#text` = `display:inline-block; width:fit-content; max-width:86vw` — NUNCA width fixa** (forma DEFINITIVA, 26/08): `width:84vw` faz a caixa pegar 84% da tela sempre, texto curto = "padding exagerado" (feedback real 2x). Só `max-width` sem fit-content ainda deixa folga em linhas curtas. A combinação exata faz a caixa ENCOLHER até a palavra mais longa (igual cabo: `max-width:86%` no player). DIAGNÓSTICO: se o feedback for "padding lateral exagerado/caixa larga demais", olhar width/display PRIMEIRO — reduzir padding não resolve se a largura é fixa.
20. **Borda da caixinha é ajustável** (25/08): `boxBorderOpacity` (0.1–1, default 0.25) + `boxBorderWidth` (1–8px @1920, default 2) em StageSettings; serializam como `boxBorderOp`/`boxBorderW` (formato APK). Sliders no StageCustomizationCard (só com boxBorder ligado), propagam pra StagePreview (cqw), views de projeção (px) e palco-session (px@1920→vh: `(w/1080)*100`). Cor fixa branca — só opacidade/espessura variam. Retrocompat: parse com clamp nos defaults.
21. **Layout Bíblia = versículo NA caixa, referência FORA abaixo** (padrão da imagem de referência do o PO, 25/08): cabo usa wrapper `__stage-inner` (flex column, gap 4vmin) com caixa justa + referência centralizada abaixo; receiver ativa `body.proj-ref-below` quando a projeção tem `footerRef` (agrupo `#footer` DENTRO do `#content` wrapper flex, `margin-top:3vh`) — sem footerRef (hinos), layout original centrado preservado. Referência `text-align:center` (era right colada na caixa). Nunca voltar referência pra dentro da caixa nem pro rodapé fixo da tela.
22. **Views de projeção NUNCA usam width fixa no container de texto** (mesma regra do #text do receiver): `BibleProjectionView.__content` tinha `width:100%; max-width:56rem` — caixa largava ~75% da tela mesmo pra versículo curto. Correto: SEM width, só `max-width` (flex item encolhe pro conteúdo) + padding `2.4vmin 4vmin` (padrão folha).
23. **TV com página ANTIGA em memória = sintoma fantasma**: mudou o receiver mas a TV continua em idle/comportamento antigo? O sender está enviando certo (confira no replay WS) — a TV abriu o HTML antes da mudança e webOS/Tizen mantêm a página viva. O servidor (:7080) serve do disco (hash confere), mas só no RECARREGAR da página da TV. Antes de debugar código, pedir reload da TV; pra validar receiver novo sem TV, abrir num Chrome headless (`google-chrome --headless=new --remote-debugging-port=9229 URL_receiver`) e inspecionar DOM por CDP — receivers novos devem ser validados assim antes de culpar o sender.
24. **Import ESM em `electron/ipc/*.mjs` usa `../palco-server.mjs`** (UM nível acima — o arquivo mora em `electron/`, não `electron/ipc/`). Caminho errado (`./palco-server.mjs`) mata o main process NO BOOT **silenciosamente**: janela fantasma 10x10 no X11, `/tmp/piano-dev.log` vazio, wmctrl sem janela, processos vivos. O antigo `require` com caminho errado "funcionava" porque o catch engolia o erro — ao trocar por `import` estático, conferir o caminho. Commit 91fedb4.
25. **Hierarquia now-playing vs letra projetada**: NUNCA renderizar `showNp` tardio (mensagem `audio action:'play'` sem URL) quando há projeção de letra ativa — o np cobre a letra com tela preta/"Reproduzindo áudio" (regressão real: fix da tela preta do MP3 quebrou o hino da liturgia). Guard antes do np tardio: letra visível → não sobrepõe. Regra: **letra projetada > now-playing**. Commit a1e99f4.
26. **Caixinha/letra do receiver = padrão exato do player `media-projection`** (pedido o PO 26/08, "mais próximo do texto"): padding `1.6vmin 1.8vmin` (vmin = proporcional em qualquer TV; lateral mínimo — evoluiu de 4vmin→2.6vmin→1.8vmin por feedback), radius `clamp(14px,2.4vmin,32px) 0 clamp(14px,2.4vmin,32px) 0`, borda `clamp(2px,.2vmin,4px)`, sombra `0 10px 30px rgba(0,0,0,.4)`, letra `weight:700; uppercase; letter-spacing:.03em`. Se o feedback for "padding exagerado", conferir pitfall 19 (width fixa) ANTES de reduzir padding.
27. **Capa da música (isCover) amarela sem caixa**: runtime media já tem `isCover`; bridge/session repassam e receiver aplica `.cover-on` = `color:#f6c32a; font-weight:900; background:none; padding:0; border:none; line-height:1.1` — paridade `media-projection__title--cover` via cabo. Lembrar de remover `cover-on` NO RESET/idle junto com box-on/shadow-on (pitfall 11).
28. **"Caixinha não aplica" → conferir ESCOPO primeiro**: `textBox:false` na mensagem com settings "ativadas" = operador ligou no escopo Global, mas hinos usam escopo **hymns** cujo override salvo vence. Não é bug de código — resolver na UI (trocar escopo/ligar lá/Redefinir override). Dica diagnóstica: `fontSize` não-default (ex.: 54 vs 96) = override existente naquele escopo.
29. **PPT/PDF último slide + Próximo = encerra** (não cíclico): no `local-pdf-player.html`, `next` no último slide chama `notifyVideoEnded()` → fecha popup + stopAllMedia + TVs idle. `prev` mantém cíclico. Herda pra `remotePptNext` (setas da TV).
30. **Hook de erro JS no receiver**: `window.onerror` + `unhandledrejection` → `sendEvent({type:'error',code:'receiver_js',message,line,col})`. Com listener WS no 7081, debuga receiver sem DevTools.
31. **pkill suicida com nomes de processo comuns**: `pkill -9 -f webOS_TV_26` casa a própria linha de comando da shell e a mata (exit -9, rm nunca roda — mesmo mecanismo do GradleDaemon). Matar por PID direto listado com `pgrep -af`.
32. **Padrão de debug WS (fechar diagnóstico sem conjectura)**: `timeout 90 node -e "const WebSocket=require('ws'); const ws=new WebSocket('ws://127.0.0.1:7081/palco'); ws.on('message',d=>{const m=JSON.parse(d); ...})"` + pedir pro usuário reproduzir na janela. Casos fechados assim: (a) hino liturgia sem letra → sender mandava certo, bug era np do receiver cobrindo; (b) Central de Mídia "não projeta" → fluxo 100% íntegro, era simulador travado; (c) caixinha false → escopo errado. EVIDÊNCIA primeiro, opinião nunca.
33. **TV LG real da sala = zona proibida sem consentimento**: família assistindo — NUNCA `ares-launch`/`ares-install`/DevTools remoto nela por iniciativa própria. Ao saber, fechar o app na TV (`ares-launch --close`). Ambiente seguro: webOS TV 26 Simulator + browser `http://<ip-pc>:7080/`. Contagem "3 TVs" com 2 aparelhos = abas órfãs do Chrome em background reconectando.
34. **Receiver servido SEM header de cache = browser preso em HTML antigo** (26/08): "funciona no simulador mas o browser mostra layout velho" com md5 idêntico em disco = cache do Chrome. O `palco-server.mjs` agora manda `Cache-Control: no-cache` no `/`, `/receiver.html`, `/index.html` (imagens/bg seguem `max-age=86400`). Mudança em main process EXIGE restart pra valer — enquanto isso, Ctrl+Shift+R resolve pontual. Sempre setar header de cache explícito em HTML servido a receivers.
35. **Debug listener WS em repo ESM** (26/08): o app tem `"type":"module"` — script node com `require('ws')` precisa de extensão `.cjs`, senão `ReferenceError: require is not defined`. Além disso o listener com `new WebSocket` sem handler de `error` morre com exceção não tratada (`ECONNREFUSED`) quando o Electron não está no ar — checar `ss -tlnp | grep 7081` ANTES de subir o listener.
36. **`npm run dev` só levanta Vite; o app desktop é `npm run electron:dev`** (26/08): pra validar Palco/bridge ao vivo, sempre `electron:dev` (Vite 5173 + Electron + WS :7081). Se o dev ficar travado sem output no spawn background, pode ser o zshrc do usuário (gitstatus/ssh-askpass) — checar portas com `ss` em vez de esperar output.
37. **Callbacks do `bindChannel` recebem `T | null`**: storage event com `newValue:null` chama `apply(normalize(null))`. Callbacks de claim/release devem tipar `(v: T | null): void` e fazer guard `if (!v) return` — senão TS2322/TS2349 (o normalize retorna o default, mas o callback do bindChannel é chamado com o retorno dele e o tipo não é nada coagido; guard explícito fecha o contrato).
38. **`window.confirm/alert` PROIBIDO no app desktop** (26/08): abre dialog nativo do Electron/SO fora do styleguide. SEMPRE `appConfirm` de `@shared/composables/useAppConfirm` (modal Vue do styleguide, Teleport to body; Liturgia e Sorteio usam). API: `await appConfirm({title, message, confirmLabel, cancelLabel?, danger?})` → boolean. Ações destrutivas (Resetar Tudo do Sorteio) com `danger: true`.
39. **Caixinha da Bíblia aplica no `<p>` do versículo, NUNCA no container** (26/08, refina pitfall 21): `BibleProjectionView` tinha `verseBoxStyle` no `__content` (versículo+referência juntos). Correto: `:style="[verseStyle, verseBoxStyle]"` no `<p>` do texto + `width:fit-content; margin:0 auto; padding:0.35em 0.75em` — a referência fica FORA/abaixo da caixa. Mesma regra do fit-content do pitfall 19.
40. **Expressão ternária como statement em TS quebra tipagem do callback** (27/08): `cond ? claim('x') : release('x')` como corpo de arrow function `(v) => { ... }` faz o TS inferir o retorno da última expressão e reclamar TS2322/TS2349 contra a assinatura `apply: (v: T) => void`. Sempre `if (cond) claim('x'); else release('x')` ou `setIntent('x', cond)`. Junto: callbacks de bindChannel tipam `(v: T | null): void` com guard (pitfall 37).
41. **Ownership por INTENÇÃO, não por nível de runtime** (27/08, spec PR #122): claim em cada mensagem de runtime + cadeia de fallback no release (`if bible.active → claim('bible')`) gera concorrência — o runtime sticky de um módulo rouba o palco do que o usuário acabou de pedir. Fix: `setIntent(o, wants)` age só na TRANSIÇÃO false→true/true→false; mensagens repetidas só re-renderizam o dono; release → idle SEM fallback. Padrão completo em references/ownership-by-intent.md.
42. **Slot atribuído com módulo inativo = tela CONGELADA sem o sweep** (27/08): `projectRouted` FILTRA slots atribuídos a outros módulos — o slot da Bíblia com Bíblia inativa não recebe nada e mantém o último versículo na TV. Fix: `sweepAssignedSlots()` ao final de TODO `projectOwner()` (inclusive branch idle): slot running + módulo atribuído no registry ≠ owner e sem conteúdo ativo → `palcoSession.idleTo(slotId)`. Tipos: `OutputModule` do registry = `bible|media|video|pdf|ppt|null` (NÃO hymns/random/timer/countdown); owner do bridge pra hinos é `'media'`.
43. **Spec no Obsidian ANTES da refactor de concorrência** (27/08): quando o usuário perguntar "como resolve isso?" sobre estado compartilhado/concorrência, escrever a spec de design primeiro (`~/ObsidianVault/04-Projects/LouvorJA PIANO/`), aprovar, depois codar — seguiu o fluxo padrão dele e evitou refactor às cegas.
44. **allowNegative do countdown (26/09/2026)**: "Continuar após zerar" — toggle existe em DOIS lugares: StageCustomizationCard.vue (segmento On/Off, escopo countdown) e CountdownConfigDialog.vue (checkbox); preview mostra tempo negativo vermelho piscando. Comportamento client-side, sem backend. Pitfall: patch que insere USO de função nova (computeRemainingRawMs, formatCountdownWithSign) sem adicioná-la ao import existente quebra o render em runtime com props corretas — validar sempre vue-tsc + vitest + curl no dev server (`curl localhost:5173/src/<path>.ts` confirma que o HMR serviu a versão nova). O botão de config do countdown é a PALETA 🎨 na toolbar do widget (title "Configuração"), não engrenagem — usuário não achou por causa do ícone.
45. **Túnel trycloudflare do user aponta pro dev server 5173 (HMR)**: mudanças em .ts/.vue refletem sozinhas no túnel; NÃO precisa build. Se HMR pegou arquivo pela metade durante edições, o render quebra com erro de Vue no console — pedir Ctrl+Shift+R antes de debugar código. Warnings de contentscript.js (MetaMask/Phantom: MaxListenersExceeded, ObjectMultiplex) são ruído de extensão, ignorar.


## Paridade APK — módulo Bíblia (buscas, 25/08)

Porta fiel do `BibleReferenceParser`/`_applyQuickSearch` do APK (`Piano-Louvor-JA-flutter/src/lib/presentation/bible/bible_reference_parser.dart`) pro desktop em `src/modules/bible/services/bible-reference-parser.ts`:

- **Busca de livro** (`bible-books__search-input`): `normalizeScriptureText` (minúsculas, sem acento, espaços colapsados) e **query ativa IGNORA o filtro de testamento** — "ap" no AT acha Apocalipse. Sem query, testamento filtra normal.
- **Pesquisar na Bíblia** (toolbar, Enter/`@search` dispara `applyBibleSearch`): tenta referência `gen 1:2`, `gn 1`, `gn 1:1-3`, `gn 1:3,5`, `gn 1:1,3-5`, `Gênesis 1:1-3`. Livro por nome/abreviação EXATOS → PREFIXO (`gn`→Gênesis), testamento-agnóstico. Navega livro+capítulo+versos e sincroniza projeção. Não-referência → filtro de texto do capítulo (comportamento legado).
- **Pesquisar versículo** (reader, Enter dispara `applyVerseSearch`): `1-3`/`2,10` seleciona range/avulsos via `parseVerseQuery` existente.
- Regex do parser (APK, não reinventar): `^([a-z]+)\s+(\d+)(?::\s*([\d,\-\s]+))?$` sobre texto NORMALIZADO.
- Pitfall: ao selecionar livro+capítulo programaticamente, `selectBook/selectChapter` zeram `selectedVerses` ao recarregar — aplicar a seleção de versos DEPOIS do `await` (corrida, mesma do APK).
- Pitfall locale (custou 2 rounds TS1117): antes de adicionar chave nova a um bloco (`settings.palco`), grep TODO o bloco pai — `tvs` já existia como label de seção. E `emit('evt')` tipado `[]` NÃO aceita payload no template; ou tipar `[value: string]` ou emitir sem arg.

## Pendência de paridade

- APK `StageModule` enum NÃO conhece `random`/`clock`/`countdown` — estender quando casting APK consumir os escopos novos.

## Suporte
- `references/cdp-validation.md` — validação ao vivo do Electron via CDP (WebSocket), receita completa.
- `references/palco-cast.md` — cast multi-TV: protocolo, slots, receiver 4 pontos, fix WS direto, roteamento por módulo, áudio.
- `references/bible-search-parity.md` — buscas da Bíblia (livro/referência/versículo) paridade APK: parser, store, UI e corrida de seleção.
- `references/timer-countdown-projection-owner.md` — owner explícito via `projecting` flag no runtime; Timer/Countdown em 00:00 ficam no Palco até Retirar, sem race com Bíblia residual.
- `references/bridge-explicit-projection-owner.md` — bridge global `palco-bridge.ts`: owner segue botão Projetar, não status do cronômetro; padrão replicável para Hinos/Liturgia.
- `references/ownership-by-intent.md` — spec 27/08: setIntent (claim/release só na transição), release sem fallback, `projecting` flag; mata a concorrência Bíblia↔Timer no Espelhar todas.
- Obsidian `00-Projects/PIANO/Palco-Arquitetura-Hibrida-Cabo-TV.md` — spec da arquitetura híbrida cabo+TV (fases F0-F3, decisões D1-D4); F0 (sync play/pause/close) implementada 25/08, F1/F2 pendentes.
- Obsidian `00-Projects/PIANO/Palco-Cast-TV-Web-Desktop.md` — log de incidentes com causa-raiz (caixinha receiver, build cabo, auto-resumo por seek).
