# WT5 Palco Cloud

> **Metodologia pública** — TVs/receivers via relay cloud. Aplica-se a qualquer stack.

---
Padrões, armadilhas e fluxo de validação para projetar conteúdo do piano-web
em receivers de TV (webOS/Tizen/AndroidTV/browser) pelo relay cloud da API.
Consultar `references/wt5-session-2026-09-01.md` para o registro técnico
completo da integração, com todas as falhas e seus fixes,
`references/wt5h-projection-parity-2026-09-03.md` para fullscreen e paridade
mensurável popup↔TV (auto-fit, linhas, referência e capitalização),
`references/wt5f-bible-stage-acceptance-2026-09-02.md` para o aceite de
personalização da BÍBLIA na TV (condições C1–C4, fixes bridge+receiver,
evidência E2E, deploy no simulator), `references/wt5g-ui-polish-2026-09-02.md`
para o polimento de UI/UX (botão Aplicar/draft, capitalização,
sobreposições, auto-fit popup), `references/wt5f-ui-polish-2026-09-03.md`
para as lições de paridade e a limitação de fullscreen automático no Chrome, e
`references/wt5f-popup-fullscreen-and-parity-2026-09-03.md` para checklist de fullscreen sem overlay e medição de quebra popup↔TV,
`references/projection-fullscreen-and-liturgy-2026-09-03.md` para o contrato Liturgia→TV, vídeo/PPT/MP3 e fullscreen sem UI intrusiva, e
`references/fake-tv-receiver.mjs`
para o receiver fake de teste E2E, e
`references/wt5h-monitor-assignment-2026-09-03.md` para detecção física,
atribuição slot→monitor, fullscreen e validação multi-monitor no web, e
`references/pwa-install-and-tunnels-2026-09-04.md` para instalabilidade PWA
do receiver (PNG 192/512 obrigatórios), topologia dos dois túneis
(API vs Vite — causa do "redirect pra home") e a decisão de descartar o
bridge Electron, e
`references/receiver-pwa-install-cache-and-identity-2026-09-04.md` para
critério de instalação real (não falso positivo), cache network-first e
identidade visual compartilhada com o Palco TV, e
`references/receiver-pwa-kiosk-multimonitor-2026-09-05.md` para o runtime
oficial multi-monitor fullscreen (Chrome kiosk por perfil isolado), detecção
da tela atual no receiver e limites X11/Wayland, e
`references/wt6-slots-kiosk-multiso-2026-09-06.md` para o ciclo 06/09:
fix do "＋ Nova tela" (window.open com FEATURES = popup bloqueado; cascata
open-sem-features → âncora target=_blank → aviso), slots por sessão
(chave global brigava entre janelas), "+ Nova tela" abre próximo slot,
kiosk `--all` injeta slot N por tela, kiosk multi-SO (.cmd/.ps1 Windows via
System.Windows.Forms.Screen — NÃO validado; macOS sem xrandr), limites duros
do PWA (1 janela, start_url perde ?slot=), túneis quick morrem com o
processo, e contraste GLOBAL de select option/optgroup em base.css, e
`references/production-culto-audio-kiosk-2026-09-06.md` para os 3 bugs de
produção no culto (popup morre com operador minimizado; áudio fora de
sincronia; receiver /palco/ NÃO implementa case 'audio' — tela branca),
kiosk browser-agnostic (Edge/Chromium/Chrome/Brave/Firefox; Safari sem
kiosk via CLI), contraste global de select e padrões de debug (túnel
morto vs API viva; validar no DOM real antes de caçar código), e
`references/production-culto-minimize-fix-2026-09-07.md` para o fix
aplicado 07/09 (root cause da cascata de minimizar + prompt de tradução +
o que é código vs dado na sync de hino).

## Modelo mental (antes de mexer em qualquer arquivo)

- **3 atores**: piano-web (operator), piano-api (`/v1/palco` relay), palco-receiver (TVs).
- **Fluxo streaming** (padrão YouTube): a TV cria a sessão e mostra QR+código;
  o web consome `?palco=CODE`.
- **Destinos independentes** (paridade com o app): rota por módulo =
  `mirror` (popup+TV) | `'tv'` (só TV, sem popup) | slot N (só popup).
- **Repositorios**: `~/piano-web`, `~/piano-api`, `~/palco-receiver`,
  `~/piano-app` (desktop, referência de contrato). Spec viva no Obsidian.

## Armadilhas críticas (cada uma já queimou uma sessão)

1. **NUNCA importar stage-relay dentro do palco-cloud-bridge.** O Vite em dev
   duplica módulos (`?t=<ts>` do HMR) e o bridge pegava instância
   `connected:false`. Comunicação via `window.__palcoRelaySend` /
   `window.__palcoRelayAudio`, registrados pelo stage-relay no `onopen`.
2. **`toggleProjection` para por `isProjecting`, nunca por `isPopupModuleOpen()`**
   (rota `'tv'` não tem popup → nunca parava). Watch de 400ms: rota `'tv'` +
   popup fechado ≠ parado.
3. **Parar projeção = publicar idle explícito no clearProjection** (runtime
   inativo/vazio). `buildRuntime.active` é só `sessão != null` — não espalhar
   flags de destino no builder (regressão na rota mirror).
4. **moduleId ≠ scope de personalização**: `media → 'hymns'` (paridade APK).
   Traduzir em UM lugar (`stageStyle` no bridge) antes de
   `readEffectiveStageSettings`.
5. **Race no attachCode**: proteger com geração (`attachGen`); reconexão usa o
   código corrente e handlers de geração morta são ignorados.
6. **Reconexão por `cid` estável** (`?cid=`, localStorage): mesmo cid expulsa o
   socket morto no servidor; cid diferente → 4409 (bloqueio legítimo).
7. **Paridade dos 3 receivers**: `webos/index.html` é a fonte da verdade — copiar
   pra tizen e conferir sha256 idênticos + rodar smokes. Sem ES2020+ (`??`,
   `?.`) no JS do webOS (WAM antigo parse-fail silencioso).
8. **BG oficial do palco → TV**: paths relativos do bundle (`/src/assets/...`
   dev, `/assets/...` prod) NÃO carregam na TV (`file://`). O bridge
   `resolveTvBackground` torna-os ABSOLUTOS com `protocol//host` do operador —
   mas SÓ se hostname for IP/hostname LAN; em `localhost`/`127.*` OMITE o bg
   (TV não resolve, cai no backgroundColor). Teste de bg real exige abrir o
   operador pelo IP da rede (Vite com `--host`). Data URL só se ≤60KB: relay
   descarta a msg INTEIRA (>64KB → msg_too_large), nunca só o bg.
9. **`proxyUrl` do receiver proxia URL http via `http://<sender-APK>:7080/proxy`**
   — no fluxo cloud o APK não roda → 502 e o bg NUNCA carrega (sintoma: bg
   sempre no fallback). Em `cloudMode` o receiver retorna a URL direta (TV
   carrega da LAN do operador web). Se um bg "nunca chega" na TV, suspeitar
   do proxy ANTES do bridge.
10. **ipk instalado ≠ repo**: receiver webOS/Tizen só ganha behavior novo após
   `ares-package` + `ares-install` com bump de versão no appinfo.json (cache
   agressivo do webOS). "Corrigi mas a TV não mudou" = reinstalar primeiro.
11. **Disk 100% trava writes** (patch/write falham "Não há espaço disponível"):
   liberar espaço ANTES de retry (logs journald/syslog, node_modules dists
   antigos). Pedir autorização antes de apagar builds/artefatos do usuário.
12. **Alinhamento no receiver: `#text` é `display:table` (shrink-to-fit) —
   `text-align` é INÓCUO na caixa.** E o alinhamento certo NÃO é reposicionar a
   caixa no canto: **paridade popup** (fix 344be71) = caixa CENTRALIZADA com
   largura total (`width:92vw`) e só o TEXTO interno alinha via `text-align`
   (o popup usa width:100%+max-width e alinha o `<p>`). Vertical sim
   reposiciona: `bottom` → `top:auto; bottom:max(pad/10.8,12)vh` +
   `translate(-50%,0)`; `top` análogo; `middle` = `translate(-50%,-50%)`.
   **Anti-sobreposição**: o rodapé (referência) fixa em `bottom:4vh` — quando
   `vAlign=bottom` o texto para em **mínimo 12vh** do chão, nunca desce até o
   footer. Sempre com RESET dos 4 lados antes de aplicar (mensagem nova pode
   trocar o alinhamento). Pad: px@1920 → `/10.8`vh vertical. Commits
   9ed3a0e→344be71 (v0.1.54), validado visualmente no simulador (left+bottom
   sem colisão com a referência).
13. **Runtime de personalização**: mudanças de settings do operador (cor,
    alinhamento, fonte) valem em TEMPO REAL — reprojetar aplica na hora, sem
    reiniciar. O que exige reinstalar é só behavior novo do receiver (ipk na TV
    física); no simulador, auto-reload da pasta aplica até behavior novo.
14. **UI de personalização tem DOIS fluxos com escopos diferentes**: a página
    Configurações → Projeção & Telas monta `<StageCustomizationCard
    only-scope="global">` — edita SOMO o escopo global. Personalização por
    MÓDULO (bible, hymns…) é no **dialog "Personalizar Palco" dentro de cada
    módulo** (botão no header, ex. header da Bíblia), que abre o mesmo card
    fixado no escopo do módulo. Sintoma de confusão: mudar alinhamento na
    página de Configurações e a bíblia na TV "não obedecer" — você editou
    global, o módulo tem override próprio que vence. Sintoma inverso: escrever
    `stage.settings.bible` direto no localStorage não reflete na UI aberta
    (store pinia em memória — recarregar a página pra sincronizar).
15. **`ares-package <dir>` grava o ipk no CWD de onde rodou**, não dentro da
    pasta empacotada. `ares-package webos/` da raiz do repo → ipk na RAIZ.
    Mover pra `webos/` (ou empacotar de dentro) pra não confundir "onde está a
    versão nova".
16. **Sobreposição texto×rodapé acontece nos DOIS lados**: no receiver (footer
    fixo bottom:4vh — fix 344be71) e no **preview web**
    (`StagePreview.vue` — `stage-preview__footer` é absoluto em
    `bottom:2.2cqw`; com `vAlign=bottom` a caixa descia até o fundo e colidia,
    fix 0af9870). O preview reserva `paddingBottom:7cqw` no container quando
    módulo=bible e showBibleVersion. Ao mudar qualquer comportamento de
    alinhamento/rodapé, aplicar a MESMA regra nos 3 lugares: receiver
    webos/tizen, popup (BibleProjectionView) e StagePreview do settings.
    Validar medição real (`getBoundingClientRect`: boxBottom < footTop).
- Popup `bible-projection__content` usa `max-width: fit-content` (fix
   11743f3, sugestão Rafael): caixa encolhe até o conteúdo real, alinhamento
   horizontal ancora no texto e não na borda de caixa larga fixa (56rem).

## Aceite de personalização do palco na BÍBLIA (WT-5f, 02/09 — validado E2E)

4 condições do Rafael: (1) bg idêntico ao configurado; (2) font-size idêntico
(`bibleFontSize`/`bibleTextColor`/`bibleFontWeight` do escopo bible — não os
do hino); (3) TODA a personalização quando houver; (4) sem personalização,
nada extra (defaults do palco = o que o popup mostra).
- Bridge `toReceiverMessage('bible')`: manda `textAlign`, `textVerticalAlign`,
  `padding`(=margin) e omite `footerRef` quando `showBibleVersion=false`.
- Receiver (webos/tizen, case 'projection'): consome alinhamentos; sem os
  campos, mantém centro padrão. Horizontal = caixa centralizada 92vw com
  `text-align` interno (paridade popup); vertical = reposiciona com mínimo
  12vh do chão (nunca sobrepõe o rodapé fixo em bottom:4vh).
- **Chaves do parse de settings são o formato APK** (`bgImg`, `tAlign`,
  `tVAlign`, `showVer`, `bSize`, `bWeight`, `bFg`, `refColor`, `refWeight`) —
  NÃO os nomes camelCase do tipo StageSettings. Testar via
  `localStorage user_data` + key `stage.settings.bible`.
- Testes de aceite C1–C4: `palco-cloud-bridge.test.ts` (7 novos).

## Fluxo de validação (evidência real, nunca declarar feito sem isso)

```bash
# API
cd ~/piano-api && npm run build && npx vitest run
# API dev
PORT=3100 REMOTE_SESSION_KEY=dev-key PALCO_RELAY_KEY=dev-key node dist/index.js

# Web
cd ~/piano-web && npx vitest run && npx vue-tsc --noEmit

# Receivers (sintaxe dos script blocks + smokes E2E contra API real)
cd ~/palco-receiver && node __tests__/wt5d-smoke.test.mjs && node browser/__tests__/smoke.test.mjs
```

Antes de commitar mudanças no receiver: extrair o `<script>` inline e rodar
`new Function(script)` (pega SyntaxError), checar ES2020+ por regex (`??`,
`?.`), copiar webos→tizen e conferir sha256 idênticos. Cuidado com
sed multi-linha no index.html: já corrompeu uma linha de bootCode (detecção:
grep do trecho editado + new Function antes de qualquer teste). Backup em
/tmp antes de edições arriscadas — e atenção que restaurar backup pode
REVERTER fixes feitos depois do backup (conferir diff vs HEAD).

Debug em browser real (Chrome DevTools MCP na página :5173): cuidado com spies
e `import()` manuais que criam módulos zumbis — validar sempre em ciclo limpo
(restart Vite + reload ignoreCache). Receiver fake de teste deve permanecer
conectado durante todo o ciclo (morrer antes da mensagem = falso negativo).

## Teste E2E sem TV física (receiver fake via WS) — validado 02/09

Dá pra validar TODO o ciclo operador→relay→TV sem TV real, direto pelo UI:

1. API dev + web dev (em dev o stage-relay já aponta pra :3100 hardcoded).
2. UI (Configurações → Projeção & Telas): "Criar sessão" → anotar código.
3. Receiver fake: `node ~/piano-api/wt5-fake-tv.mjs <CODE> <TOKEN>` (token via
   `GET /v1/palco/sessions/<CODE>/token`). Conecta `role=receiver`, cid estável,
   loga toda msg recebida. Deve ficar conectado o ciclo todo (morrer antes =
   falso negativo). Referência do script em `references/fake-tv-receiver.mjs`.
4. Operar o web de verdade (Mídia → hino "Cantado"; Bíblia → versículo →
   "Projetar") e conferir no log do fake: projection v2 completa (título,
   background, fontSize, stage fields), audio play/pause/stop, e **idle
   explícito** ao fechar/encerrar. "TV1 · 1 TV conectada" no UI confirma o
   receiverList do youare. "Encerrar sessão cloud" restaura o estado inicial.
5. Detalhe UX: "Fechar" do player abre confirm "Deseja fechar essa música?" —
   confirmar "Sim" pra ver o idle chegar na TV.

Armadilha de teste: pong responde no socket que enviou o ping (operator), não
no receiver — capturar as respostas no socket correto ao fazer assert.

## Simulator webOS (sem TV física, validado 02/09)

AppImage em `~/Apps/webOS_TV_26_Simulator_1.5.0.AppImage` (ext4 — ok).
Device `emulator` (127.0.0.1:6622) já registrado no `ares-setup-device` e é o
DEFAULT, então `ares-install <ipk>` nem precisa `--device`.

**Armadilha**: abrir o AppImage só sobe o LAUNCHER (gerenciador de TVs
virtuais) — a porta 6622 fica FECHADA e `ares-install` dá
`connect ECONNREFUSED 127.0.0.1:6622`. É preciso criar/iniciar a TV virtual
na GUI do launcher (botão "+ Create" → webOS TV 26). Depois disso:

**Armadilha — janela preta**: o launcher PODE abrir com a janela toda preta
(sem menubar) — parecem morto, mas o processo está vivo. Matar
(`pkill -9 -f webOS_TV`) e relançar resolve; ao reabrir a janela mostra a
home da TV virtual JÁ BOOTADA (inclusive apps instalados de sessões
anteriores). Conferir a tela REAL via `import -window <id> /tmp/sim.png`
(xdotool search --name "webOS TV 26" pega o window id) + vision — o capture
do computer_use pode vir 0x0 ou com overlay de notificação.

**Porta 6622 fechada mesmo com TV bootada**: a porta dev só abre ao ligar o
**Key Server** no menu Tools do simulator (ou app Developer Mode dentro da
TV virtual). Sem isso o `ares-install` continua dando ECONNREFUSED.

**Operar GUI com usuário presente**: checar SEMPRE se há jogo/app fullscreen
antes de clicar (`computer_use list_windows` ou screenshot root) — um clique
no desktop com jogo abento vai pro JOGO, não pro simulator. O terminal
(xdotool/import) não rouba foco e é o caminho seguro para inspecionar; clicar
só com consentimento explícito.

```bash
cd ~/palco-receiver && ares-package webos/     # ipk na raiz do repo
ares-install com.piano.louvorja.palco_0.1.53_all.ipk
ares-launch com.piano.louvorja.palco
```

**Descoberta-chave (02/09): o simulador NÃO instala ipk — roda a PASTA direto.**
`~/.config/webos-simulator/webos-tv-simulator-26.json` → `appEntries:
["~/palco-receiver/webos"]` com `auto-reload: true`. Editar
`webos/index.html` no repo tem efeito IMEDIATO na TV virtual (auto-reload,
conferir a label "receiver vX" no canto do idle). Isso inverte o fluxo no
simulador: NÃO precisa `ares-package`/`ares-install`/Key Server/6622 —
bump de versão no index.html serve só pra confirmar que o reload pegou.
O ipk continua sendo o caminho pra TV FÍSICA. Para reconectar a TV virtual
numa sessão cloud nova sem digitar código: hack temporário de hardcode do
código no bootCode do index.html (auto-reload reconecta) — REVERTER antes
de commitar. Teste de bg no simulador exige operador aberto por IP LAN
(Vite `--host 0.0.0.0`); atenção: localStorage do operador é POR ORIGEM —
`localhost:5173` e `192.168.x.x:5173` têm EULA/configs/sessão separadas.

## TV no browser (receiver webOS via HTTP puro — validado 02/09)

O receiver é HTML/JS puro: roda direto no Chrome, sem simulador nem TV.

```bash
cd ~/palco-receiver/webos && python3 -m http.server 8080   # em background
# abrir:
http://localhost:8080/?api=ws://localhost:3100/v1/palco&code=<CODE>&debug=1
```

- **NUNCA usar `npx serve`**: ele 301 `/index.html?query` → `/` DESCARTANDO a
  querystring — o receiver perde `?api=` (cai na API de PRODUÇÃO,
  wss://api.Piano-Louvor-JA.com.br) e `?code=` (não conecta). Sintoma: network
  mostra `GET https://api.louvorja.com.br/v1/palco/sessions/<CODE>/token [404]`
  com sessão que existe na API local. `python3 -m http.server` serve sem
  redirect. Confirmado no log do serve: `/index.html?... → 301 → /`.
- Navegar por `/` (não `/index.html`) evita o redirect de vez.
- Depois de conectar 1x, `palcoCloudCode` fica no localStorage da origem
  `localhost:8080` — reabrir `http://localhost:8080/` reconecta sozinho
  (mas `?api=` não persiste: sem ele, volta pra API de produção).
- `&v=dev` sobrescreve a label de versão do idle (útil pra confirmar reload).
- Validar o ciclo: operador (`:5173`) publica → a aba-TV recebe projection
  igual à física (bg, alinhamento, cores). Se ficar preso no idle: a
  operadora pode ter perdido a sessão após reload — reconferir o card TVs
  (código ativo) antes de caçar bug no receiver.

Vale tudo do skill webos-tv-app-development (browser constraints, cache).
O simulator carrega URLs do bg que o operador mandar — pra testar bg oficial
precisa do operador aberto por IP LAN (Vite `--host`); localhost é omitido
pelo bridge de propósito (pitfall 8).

## Computer use / cua-driver (setup do daemon)

`computer_use` falha com "cua-driver session setup failed" quando o daemon
não está rodando. Diagnóstico: `ls -la ~/.cache/cua-driver/cua-driver.sock` —
se a data do sock for antiga, o daemon morreu e sobrou sock órfão. Fix
validado 02/09:
```bash
cua-driver update --apply   # versão velha (ex. 0.11.0) falha o handshake do MCP
pkill -f "cua-driver serve"; rm -f ~/.cache/cua-driver/cua-driver.sock ~/.cache/cua-driver/cua-driver.pid
cua-driver serve &          # background; conferir sock recriado com data nova
```
Depois disso `computer_use` volta a funcionar sem reiniciar a sessão.

**Chrome DevTools MCP pode travar (TimeoutError em todo call) quando o
Chrome está sob carga pesada** (ex.: jogo em fullscreen em outro monitor +
dezenas de abas). Os calls `list_pages`/`select_page` dão timeout de 300s em
loop — não insistir. O Chrome e os servidores continuam vivos (curl
responde); é o canal CDP que não atende. Recovery: fechar abas pesadas ou
esperar o usuário liberar carga. Enquanto isso, validar por caminhos sem
browser: smokes, testes unitários, logs do receiver fake, e pedir screenshot
ao usuário.

17. **Referência da bíblia (footer) segue o alinhamento do palco** (fix
    60185f4): o `#footer` do receiver tinha `text-align:center` FIXO — o texto
    principal alinhava mas a referência ficava sempre centralizada, quebrando
    a paridade com o popup (lá a referência fica DENTRO do bloco de conteúdo,
    alinhada junto). Fix: o footer aplica o mesmo `m.textAlign` com padding
    `0 4vw` (mesma borda da caixa de 92vw); sem o campo, mantém centro (C4).
    Ao mudar alinhamento, considerar SEMPRE os 3 elementos: caixa de texto,
    rodapé e preview.
18. **Botão "Aplicar" no Personalizar Palco** (fix 805118d, UX Rafael): o card
    edita um DRAFT local (`effectiveSettings = draft ?? settings`) — preview
    reage em tempo real mas `patch()`/persist/notify SÓ ocorrem no clique em
    Aplicar (Cancelar descarta). Motivo: cada tick de slider gerava
    patch→save→notify→publish no relay (dezenas de projections, TV piscando).
    Helpers de sub-objeto (`patchClock`, `patchModuleTimeFormat`,
    `patchRandom`) também leem o draft. i18n: `common.apply` (pt/en/es).
    Validar com localStorage: ajustar slider NÃO muda `user_data`; Aplicar
    sim. Novos controles no card devem usar `draftPatch()`, nunca `patch()`.

19. **Capitalização do versículo (bíblia)** (17a8508 web / 1cba051 receiver):
    `StageSettings.bibleTextTransform` (`none|uppercase|capitalize`, chave APK
    `bTransform`, default `none` — retrocompatível). Popup aplica CSS
    `text-transform` no verseStyle; bridge manda `textTransform` no envelope v2
    SÓ quando ≠ none; receiver aplica no `#text` com reset por mensagem. UI:
    segmento Normal/MAIÚSCULAS/Capitalizado na seção Bíblia do card (draft+
    Aplicar), i18n `settings.stage.bibleTextTransform`/`transformNone`/
    `transformUppercase`/`transformCapitalize` (pt/en/es). Validado E2E no
 receiver browser (uppercase + caixinha + right/bottom).

 20. **Referência FORA da caixinha + label de versão some** (c0bbafb, print
 Rafael 02/09): a referência ficava DENTRO da borda da caixinha e colidia
 com o label `idleVer` (fixo bottom:3.2vh right:3vh, z-index 9999). Fix:
 (a) `#footer` com `footerRef` sobe pra `bottom:8vh` (fora da área da
 caixinha que desce até 12vh), voltando a 4vh sem referência; (b) `idleVer`
 recebe `display:none` durante projection com referência, volta no
 idle/other cases. (c) Padding interno da caixinha reduzido
 `1.6vmin 1.8vmin` → `0.9vmin 1.2vmin` (caixa mais justa ao texto,
 versículo curto cabe em menos espaço — pedido explícito do Rafael).
 (d) O PREVIEW também reflete `bibleTextTransform` (d991a59) — ao adicionar
 qualquer campo visual novo, lembrar do StagePreview: é a 4ª superfície que
 esperta o mesmo comportamento (popup, bridge, receiver, preview).

21. **Auto-fit do popup (a8aa2b5) — versículos múltiplos estouravam a tela**:
    o receiver tem auto-fit próprio (rAF loop no webos), mas o POPUP
    (BibleProjectionView, usado na projeção cabeada pros monitores) não tinha
    nada — Gn 1:1–3 com fonte 120px cortava em cima. Fix: `applyFit()` mede
    `scrollHeight` vs 86% da altura do palco e reduz um `fitScale` que entra
    no fontSize cqw do verseStyle (NÃO setar fontSize inline — o Vue
    re-render sobrescreve). Dispara em: troca de texto/settings,
    resize da janela e **re-montagem do bloco** (a Transition out-in troca o
    nó do DOM — o fit antigo não serve; watch em showContent + nextTick).
    Sintoma de "watch não dispara na 1ª projection": o texto chega antes do
    layout assentar — o resize manual disparava e funcionava, daí o watch em
    showContent. Paridade popup↔TV de auto-fit completa.

22. **Referência fora da caixinha NO POPUP também** (c7fa44c): após o fix do
    receiver (item 20), o popup ficou inconsistente — a referência ficava
    DENTRO do `bible-projection__content` (a caixinha). Fix: novo wrapper
    `__stack` (column, gap 1.4vmin) que recebe o `stageAlign` (alinha o
    PAR caixinha+referência conforme textAlign/textVerticalAlign); a
    `__content` abraça só o versículo e a `__reference` vira IRMÃ fora do
    box. Medição de aceite: `getBoundingClientRect` → ref fora do box,
    gap ~14px, texto dentro, tudo na tela. Estrutura: stageAlign vai no
    `__stack`, não mais no content.

23. **QR+código na TV e auth (decisão de design, 03/09)**: o idle da TV
    deve mostrar código da sessão + QR (paridade com o popup). O QR NÃO
    precisa de login atrás: role=receiver é read-only (uma TV a mais só
    espelha, não controla). Recomendado: QR embute `?palco=CODE`
    (+ opcionalmente token efêmero da sessão — nível 2) — o código
    efêmero de 6 chars É a credencial (modelo WhatsApp Web/Kahoot). Auth
    de usuário só faria sentido se o QR desse direito de OPERAR. Não
    implementado ainda.

24. **Paridade TOTAL da referência popup↔TV** (9ee069f, 03/09 — prints
    comparativos #6 popup vs #7 TV): estilo E posição. (a) `#footer .ref`
    recebe `text-transform:uppercase` + `letter-spacing:.02em` + opacity 1
    (era .7 e minúsculas — o popup usa uppercase na
    `bible-projection__reference`); `.ver` reseta os dois (fica lowercase).
    (b) Posição: o footer NÃO fica mais no rodapé fixo da tela quando há
    `footerRef` — o rAF do auto-fit mede o `rect` da caixinha e ancora o
    footer ABAIXO dela: `left/width` do rect + `top = rect.bottom + 1.4vh`
    (gap do `__stack` do popup), clampado pra não sair da tela. Sem ref:
    left/right 0, top auto, bottom 4vh. SEMPRE resetar left/right/width/top
    no case footer antes de aplicar (mensagem sem ref não pode herdar a
    âncora da anterior). Diferença residual honesta: line-height da TV
    (~8% maior que o clamp do popup) — perceptível só lado a lado.

25. **Multi-destino por TV — decisão de produto (03/09, WT-6)**: Rafael
    quer conteúdo DIFERENTE por TV (TV1=Bíblia, TV2=Música). Escolhido o
    **modelo A (TVs como "áreas")**: operador atribui cada TV a um módulo
    na UI; sem atribuição = broadcast (comportamento atual). Design:
    envelope ganha `to:'<cid>'` opcional; `routeMessage` entrega só pro
    cid alvo quando presente; `lastStateBySender` vira mapa por cid
    (late-join recebe só seu estado); receiver ignora `to` de outro cid
    (defesa); bridge publica N vezes (uma por grupo). A UI de TVs
    conectadas vira lista com dropdown por TV. NÃO implementado ainda.

26. **Popup fullscreen no CHROME (e3a21cc + 7bcb6e4, 03/09)**: TRÊS
    caminhos impediam o fullscreen. (1) `fullscreen=yes` do
    `window.open` é IGNORADO por navegadores — só Electron respeita;
    fullscreen real no Chrome = Fullscreen API, `requestFullscreen()` no
    mount da PopupHost (a popup herda a user activation do clique que a
    abriu). (2) `openPopupModule` re-aplicava bounds salvos via
    `scheduleRestoreOnWindow` após a permissão de window management.
    (3) A própria PopupHost chamava `restoreLayout()` no mount e se
    encolhia de volta. Fix: restore é EXCLUSIVO da janela de controle da
    liturgia; telas de projeção nunca se restauram. Aviso "pressione
    ESC" do Chrome por ~1s é inerente ao navegador — não remover.

27. **Paridade de quebra de linha popup↔TV (acc3664, 03/09)**: mesmo
    texto, popup=3 linhas vs TV=4. Causa MEDIDA: popup usa área útil
    `calc(100vw - 12vmin)` (stage padding 6vmin/lado), `line-height:1.45`
    e sem letter-spacing; receiver usava `92vw`, `1.25` e `.03em` — e o
    auto-fit SÓ vertical não reduz (4 linhas ainda cabem na altura).
    Fix: no case projection bíblica o receiver aplica as métricas do
    popup, com reset para hinos/outros módulos. **Lição: paridade visual
    se valida MEDINDO os dois lados** (font-size/line-height/largura
    útil/contagem de linhas via getBoundingClientRect), não comparando
    prints no olho. Spec: Obsidian `04-Projects/PIANO/WT-5F-projecao-
    fullscreen-e-paridade-tipografica.md`.

## Estado aberto (atualizar conforme evolui)

- Liturgia-web: wire relay EXISTE (WT-5G); kind `audio` portado (f4ce42c, WT-6 item 1).
  Restam: botão "Espelhar para TVs" explícito no vídeo + validação de URL
  acessível pela TV; blob: do operador nunca chega à TV (exige upload/serving
  na API — próximo ciclo). Áudio no cloud ainda vai pra todas as TVs
  (roteamento por cid pendente).
- Áudio no cloud vai pra todas as TVs (roteamento por cid pendente).
- **BUG CRÍTICO pós-culto (06/09): receiver `/palco/` não implementa
  `case 'audio'`** (descarta envelope com console.debug) — sem player de
  áudio na TV, hino toca só no operador, tela branca até imagem resolver,
  sem sincronia. Fix planejado (aguarda confirmação do Rafael que o som
  deve sair da TV): `<audio>` no receiver + positionMs do envelope +
  now-playing/cover/equalizador. Full doc em
  `references/production-culto-audio-kiosk-2026-09-06.md`.
- Popup morre quando operador é minimizado (window group) — reforça a
  direção de produto: projeção via relay/TV independente, popup só local.
- Teste em TV física nunca feito; label de TV é genérico.
- Visual final (footer @8vh + padding caixinha menor + idleVer oculto na
  projection) commitado (c0bbafb) mas validação VISUAL no simulador ficou
  pendente — Chrome CDP travou no fim da sessão 02/09. Conferir na TV
  virtual/browser ao reabrir; smokes+sintaxe já passaram.
- ipk 0.1.54 atual (c0bbafb) em `~/palco-receiver/webos/` pronto pra TV física
  via ares-install.
- Wave 2 (02/09): TV real não aplicava bg — 3 causas em cadeia: (a) operador
  em localhost gera URL inacessível → web 8c43516 omite bg se hostname for
  localhost/127 (URL real exige operador aberto pelo IP, Vite `--host`);
  (b) proxyUrl do receiver proxia tudo pro APK :7080 (502 no cloud) →
  receiver 2e654cc `if(cloudMode) return original;`; (c) behavior de
  alinhamento só sobe na TV com ares-package + ares-install (bump appinfo).
  Detalhe completo em `references/wt5f-bible-stage-acceptance-2026-09-02.md`.
- Idle da TV sem código+QR (paridade com popup, item 23) — desenho decidido
  (sem login; código efêmero como credencial), a implementar.
- Multi-destino por TV (modelo A, item 25) — IMPLEMENTADO como WT-6A
  (roteamento por slot, 05/09): receiver declara `?slot=N`, envelope `to:
  slot-N`, web roteia via rota `palco:N` no seletor do módulo. Commits
  api 73509ca / web adf2004. Contrato completo e pendências (E2E real,
  áudio broadcast, UI dropdown) em
  `references/wt6a-slot-routing-2026-09-05.md`.
- Paridade da referência validada visualmente no simulador (03/09,
  print sim16: uppercase + ancorada abaixo da caixinha). ipk 0.1.54
  atual (acc3664) em `~/palco-receiver/webos/` pra TV física.
- Paridade popup↔TV de quebra de linha (3 vs 4 linhas) e fullscreen do
  popup no Chrome: fixes aplicados (e3a21cc, 7bcb6e4, acc3664) mas
  validação VISUAL final pendente — simulador ficou preto/minimizado e
  CDP do Chrome indisponível no fim da sessão 03/09. Primeiro passo da
  próxima sessão: projetar Gn 50:4–5 e MEDIR os dois lados.
28. **Recovery pós-desligamento do PC (04/09)**: quando o PC morre no meio do ciclo, PRIMEIRO checar estado dos repos (`git status -sb`, `git log`, `git fetch` + `@{u}..HEAD`) antes de assumir perda — o padrão "commitar+push ao fim de TODO ciclo" costuma deixar tudo salvo; a perda real costuma ser só: (a) upstream branches não configurados (`git push -u origin <branch>` repara), (b) servidores dev (Vite/API/túnel cloudflared) mortos — subir de novo, (c) arquivos em /tmp (perdidos MESMO com commit: scripts Telethon, DBs de teste). Session search pelo tópico recupera o plano e o "próximo passo imediato" — começar por ele, não re-planejar do zero.

29. **Estender um kind de mídia na Liturgia web (padrão WT-6, áudio)**: o pipeline de liturgia-web tem ~8 pontos que filtram por `kind` — esquecer UM quebra sync/playback silenciosamente. Checklist completo ao portar um tipo novo do app: `types/liturgy.ts` (5 listas), `liturgy-web-runtime.ts` (union + normalize), `liturgy-web-projection.ts` (control+screens), `liturgy-actions.ts` (execute+play), view de projeção (guards + template), `liturgy-ja-import.ts` (extensões), `palco-cloud-bridge.ts` (branch relay), i18n ×3 locales. Teste de bridge cobre: envelope correto, blob: → idle com aviso honesto, inativo → idle.

30. **Túneis cloudflared são DESCARTÁVEIS — morrem a cada desligamento/restart;**
    URLs novas a cada sessão (nunca reutilizar URL antiga de referência/skill).
    Recovery padrão: `pgrep -af cloudflared` → para cada serviço morto, subir
    `cloudflared tunnel --url http://localhost:<porta> --logfile /tmp/cf<porta>.log`
    em background e extrair a URL com `grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cf<porta>.log`.
    **Armadilha de diagnóstico**: o erro "Falha ao consultar o palco do desktop"
    (`settings.palco.statusError`) é GENÉRICO — o card reutiliza o mesmo texto
    para falha do relay cloud. Túnel da API morto → esse erro aparece sem
    desktop nenhum envolvido. Sempre checar túneis/health antes de caçar bug.
    **Operador via túnel do Vite**: em dev o stage-relay aponta
    `localhost:3100` (quebra pra quem acessa remotamente) — passar
    `?palcoApi=<túnel-da-API>/v1/palco` na URL do operador (ou
    `localStorage.palcoApiBase`). Melhoria pendente: diferenciar a mensagem de
    erro relay vs desktop e default same-origin em dev-aberto-por-túnel.
    **Armadilha `.env.local` (causou o bug "parou de gerar o código", 04/09)**:
    `VITE_PALCO_API_URL` é EMBUTIDO no bundle pelo Vite no boot — se apontar
    pra um túnel trycloudflare, quando o túnel morrer TODO `createSession()`/
    `bootstrapToken()` falha (CORS/ERR_FAILED no console) e o card mostra
    "Falha ao consultar o palco do desktop" sem nenhuma pista de túnel.
    Diagnóstico: `grep VITE_PALCO_API_URL ~/piano-web/.env.local` + console do
    Chrome mostrando fetch pro host morto. Fix: deixar a var VAZIA no
    `.env.local` (default: localhost:3100 em dev, same-origin em prod) e usar
    túneis só via `?palcoApi=` (runtime, nunca bundle). Mudou o `.env.local`?
    PRECISA reiniciar o Vite (env só é lido no boot) — o card não volta a
    funcionar com HMR sozinho.
31. **Reproduzir bug de UI no browser antes de caçar código** (04/09,
    "parou de gerar o código"): console do Chrome (DevTools MCP) mostrou na
    hora os fetches falhando pro túnel morto — diagnóstico em ~2 min depois
    de duas rodadas de suposição às cegas. Padrão: abrir a página real,
    clicar o botão real, ler console + network, SÓ DEPOIS tocar no código.
32. **Elemento "visível" no DOM mas invisível na tela**: checar
    `getBoundingClientRect` + computed display de cada ANCESTRAL — um
    container com `display:none` (ex.: `#setup` escondido ao conectar)
    engana o `!classList.contains('hidden')` do próprio botão. Confirmar
    com screenshot + vision antes de declarar "apareceu".

33. **UX para usuário LEIGO é critério de produto, não nice-to-have (05/09,
    feedback direto do Rafael)**: ao propor qualquer fluxo, perguntar
    "um coordenador de louvor sem conhecimento técnico consegue fazer
    sozinho?". Terminal/curl/chmod NÃO é caminho principal — é opção
    avançada escondida (ícone pequeno com tooltip). O caminho principal
    vira botão no PWA: `+ Nova tela` (window.open da mesma URL → cada
    janela conecta sozinha na sessão e vira monitor novo na lista do
    operador), `Instalar app`, `Detectar esta tela`. Limite honesto a
    declarar na UI: a janela nova abre no monitor do Chrome — o arraste
    pro monitor alvo é o único gesto manual (fullscreen automático
    multi-monitor garantido só via palco-kiosk.sh no boot da máquina).
34. **Botões com comando/URL longos quebram o card** (05/09): o botão
    "Copiar comando" com texto do comando inteiro estourou o layout da
    seção Monitores receiver. Padrão: ação vira ÍCONE compacto
    (`.palco-slots-card__icon-btn`, 1.8rem, flex:none) com comando no
    `title`/tooltip + feedback de check 2s. Regra geral no card: texto
    curto de ação no botão; payload longo (URL, comando, diagnóstico)
    vai no tooltip/clipboard, nunca renderizado na UI.
35. **Multi-instância do receiver**: `window.open(location.href)` com
    `popup=yes` abre janela sem barras já conectada (código via URL →
    localStorage). Validado: cada janela vira um "Monitor N" novo no card
    do operador. `screenInfo` (detectar tela) exige clique para pedir
    permissão `window-management` — botão discreto, não auto-prompt.
    **CORREÇÃO 06/09**: `popup=yes` e QUALQUER feature no 3º argumento de
    `window.open` ativa o bloqueador do Chromium (aba E PWA — reproduzido
    nos dois). Fix em cascata: `window.open(url,'_blank')` sem features →
    âncora sintética `target="_blank"` → aviso. Detalhe e evolução
    (slot por janela, kiosk multi-SO) em
    `references/wt6-slots-kiosk-multiso-2026-09-06.md`.
36. **Watcher em janela operadora NUNCA decide teardown com document.hidden (fix
    8401199, bug de culto 06/09 — popup/TV morria ao minimizar o operador)**:
    o browser THROTTA setInterval de janela oculta e o estado da popup fica
    ilegível nesse tick. Padrão: 1º comando do tick = `if (document.hidden)
    return`; `visibilitychange` republisha runtime no relay ao voltar e deixa
    o próximo tick (timers vivos) cuidar de reopen/teardown; cleanup simétrico
    do listener. Aplicável a QUALQUER watch/timer de estado em janela que o
    usuário minimiza.
37. **Sync de hino: separar bug de CÓDIGO de limitação de DADOS (06/09)** —
    tela branca no início = publish ANTES do play (fix: publishProjectionState
    antes de playMediaAudio no open()); sincronia frase-a-frase = catálogo
    estático NÃO tem tempos reais (1889 músicas, zero lyric estruturada,
    `lyric` é plain string `\r\n` → todos os slides em 00:00:00). Sync perfeita
    exige dados no catálogo — não caçar bug no player.
38. **Prompt "Traduzir página" na projeção**: `translate="no"
    class="notranslate"` no `<html>` de `piano-web/index.html` E de
    `piano-api/static/palco/index.html` (receiver /palco/ é servido pela API,
    não pelo Vite — por isso o html separado).
39. **cloudflared quick tunnel morre SOZINHO por auto-update** (07/09):
    `cloudflared has been updated` → graceful shutdown do processo; e um
    processo vivo pode ter conexão interna morta (530 na URL). Recovery:
    `pgrep -af cloudflared` + curl de health na URL; matar órfãos e subir de
    novo (novos hostnames SEMPRE). Ler hostname novo via
    `curl http://127.0.0.1:<metrics>/metrics | grep -oE
    'https://[a-z-]+\\.trycloudflare\\.com'` (métricas 20241/20242) quando o
    log não estiver à mão. Validar endpoint REAL (ex. `/json_db/pt_categories`
    200) antes de declarar o túnel são — 404 em rota inexistente não prova
    nada sobre o túnel. Ver item 30 (padrão geral de túneis descartáveis).
40. **Paridade das variantes do receiver é GATE DE CI, e o AndroidTV é o
    elo que sempre atrasa** (11/09, PR #11 travada desde 05/09): o repo
    `~/palco-receiver` tem 4 variantes — webOS (`webos/index.html`, canônica),
    Tizen (`tizen/index.html`, DEVE ser byte-a-byte idêntico ao webOS),
    AndroidTV (`androidtv/assets/palco/receiver.html`, WebView carregando o
    MESMO html — DEVE ser idêntico ao webOS) e browser (`browser/index.html`,
    standalone POR DESIGN, com features desktop próprias como "+ Nova tela" —
    fora do gate). O CI "Paridade receiver (webos vs androidtv)" faz
    `diff -q webos/index.html androidtv/assets/palco/receiver.html` e falha
    o merge se divergirem. Sintoma crônico: o AndroidTV ficou 89 linhas atrás
    (9 refs WT-5 vs 17) sem ninguém perceber. Recovery: `cp
    webos/index.html androidtv/assets/palco/receiver.html` + commit na branch
    da PR. Ao mudar o receiver webOS, SEMPRE copiar pra tizen/ E
    androidtv/ no mesmo commit — nunca "deixo pra depois".
41. **Lint de CI "hardcoded credential" que casa concatenação de variável é
    falso positivo** (travou a mesma PR): a regex
    `(passwd|password|pwd|token|credential|secret)\s*[:=]` barrou o
    `?token='+encodeURIComponent(token)` do WebSocket cloud. Correção no
    workflow: exigir valor LITERAL entre aspas
    `...\s*[:=]\s*['\"][^'\"]{4,}['\"]` + filtrar `\+encodeURIComponent`.
    Nunca renomear a variável de código pra agradar o grep — conserta-se o
    padrão do lint (é workflow próprio). Validar a regex nova localmente
    contra o arquivo real ANTES do push (concatenação `'token='+var` ainda
    casa por causa da aspas de fechamento).
42. **Paridade de feature entre variantes tem exceções LEGÍTIMAS por
    plataforma**: "+ Nova tela" (multi-monitor PWA) existe só no browser —
    webOS/Tizen não têm popup/window.open. Não "portar" por paridade cega:
    a paridade obrigatória é de COMPORTAMENTO DO RECEIVER (projeção, relay,
    áudio, customização), não de cada botão. O gate de diff byte-a-byte é
    webOS↔Tizen↔AndroidTV; o browser evolui à parte (validar os smokes dele:
    `node browser/__tests__/smoke.test.mjs`).
```
