# LouvorJA Remote Pairing

> **Metodologia pública** — pareamento/controle remoto entre dispositivos. Aplica-se a qualquer stack.

---
## Modelos de conexão (decisão final 2026-08-23)

| Par | Quem serve | Fluxo QR | Status |
|---|---|---|---|
| Desktop → APK | Electron WS :7071 | 1 QR (`louvorja://connect?host=IP:PORT&token=X`) no desktop, APK escaneia | ✅ produção |
| Web ↔ APK | **APK serve WS** (web link) | **1 QR** (`ws://IP-do-celular:PORT?t=TOKEN`) no celular, **web escaneia com webcam** (jsQR) | ✅ aprovado |
| Web ↔ APK (WebRTC P2P 2-QR) | ninguém (DataChannel) | offer QR → APK answer QR → web lê com webcam | ⚠️ código existe mas REPROVADO como fluxo principal |

### Por que o 2-QR WebRTC foi reprovado (lição de UX)
- Rafael: "o ideal é q o usuario não tenha q colar nada e que ja seja possivel resolver só com o qr" — 2 trocas (offer + answer) = fricção estrutural, não ajustável.
- Bugs reais encontrados: (1) `onIceGatheringState=complete` do flutter_webrtc não dispara confiavelmente — answer saía só com candidatos loopback (127.0.0.1) e nunca conectava. Fix: escutar `onIceCandidate` (não `onCandidate` — nome errado da API) + idle timer 1.5s. (2) `SelectableText` com `maxLines: 3` trunca na cópia — SDP copiado incompleto = answer "inválido".
- Regra geral: quando um lado tem câmera e o outro tem tela, o lado com CÂMERA escaneia; o lado que pode SERVIDOR (WS embutido) serve. 1 QR, 0 digitação.

## Protocolo
JSON sobre WS/DataChannel, proto v1.2 (RemoteCommand/RemotePlayerState). Mesmo shape nos 3 transportes.

## Estrutura de código
- APK: `lib/core/services/remote/` — `remote_session.dart` (orquestra modo desktop/web), `desktop_connection.dart` (WS cliente), `web_link_server.dart` (HttpServer WS — servidor pro web), `p2p_remote_client.dart` (WebRTC, secundário)
- APK UI: `lib/presentation/settings/widgets/remote/remote_section.dart` (QR scan + web link + QR do web link); `lib/presentation/remote/unified_qr_scanner.dart` (scanner que CLASSIFICA payload)
- Web: `src/modules/remote/views/WsPairingView.vue` (webcam→WS), `P2pPairingView.vue` (legado), `services/p2p-remote-host.ts`
- Rota web: `/settings/remote` — `isElectronShell() ? RemotePairingView(WS desktop) : WsPairingView(scan)`

## Scanner QR unificado — SEMPRE classificar payload
QR pode ser: `louvorja://...` (desktop WS), `ws://...` (APK web link), `{sdp,type}` JSON (P2P offer). O scanner classifica (`startsWith('ws://')` / JSON parse com `sdp`+`type`) e roteia. Nunca hardcode um formato só — Rafael bateu o olho nisso ("apk acusa q o qr do web não é valido pq de fato não é").

## QR libs (nomes exatos — já errei)
- Flutter: `qr_flutter` → widget `QrImageView`, enum `QrErrorCorrectLevel.L/M` (não `QrErrorCorrectionLevel`, não `QrErrorCorrections`). Leitura: `mobile_scanner`.
- Web: gerar `qrcode` (`QRCode.toDataURL`), ler `jsqr` (export default `jsQR` — pacote `jsqr`, não `jsQR`) + `getUserMedia` + canvas `getImageData` a cada 250ms.
- SDP em QR: error correction L (payload ~1-2KB). URL WS em QR: M.

## Repos e versões
- `Piano-Louvor-JA/app` = Electron desktop (v1.17.x)
- `Piano-Louvor-JA/web` = PIANO web novo (v1.18+, Vue3+Vuetify4+Vite8, módulos espelhados, SEM remote ainda) — **base futura do web; não desenvolver remote no repo app/web antigo**
- `Piano-Louvor-JA/apk` = Flutter mobile

## UX por plataforma (cobrança explícita do Rafael)
- Web não tem auto-update nem dados locais desktop → NÃO copiar seções "Atualizações"/"Dados locais" pro settings web.
- Features nascem JUNTAS em desktop+web+APK quando da mesma família (liturgia/controle) — senão Rafael cobra depois.

## i18n pitfalls (webapp Vue)
- Locale TS com aspas simples QUEBRA o build oxc se a string contém apóstrofo (`phone's`) — usar aspas duplas. Aconteceu 2x na mesma sessão.
- Teste de locale-parity existe e falha em chaves faltantes — rodar `vitest run src/plugins/__tests__/locale-parity.test.ts` ao mexer em locale.
