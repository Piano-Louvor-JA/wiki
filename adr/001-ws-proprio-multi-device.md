# ADR-001: Comunicação multi-device via WebSocket próprio (não Chromecast)

**Status:** Aceita · **Data:** 2026 · **Decisor:** Rafael

## Contexto

Precisamos projetar conteúdo (hinos, liturgia, bíblia) em telas externas:
TVs de igreja, monitores secundários. As opções óbvias de mercado são
Chromecast/AirLink, mas a realidade das igrejas-alvo é variada (TVs antigas,
Android TV, webOS, Tizen, sem internet estável).

## Decisão

A TV é um **dumb display** controlado pelo cliente (desktop, web ou celular)
via **WebSocket próprio**:

- O receiver (`palco-receiver`) roda na TV (webOS/Tizen/AndroidTV/web) e
  conecta-se ao cliente — nunca o contrário.
- O APK inclui o cast (StageSession): o **celular** é a fonte da projeção.
- Para TVs que não conseguem conectar direto na rede local, existe relay cloud
  (ver skill wt5-palco-cloud).

## Consequências

- ✅ Funciona em qualquer TV com navegador/embedded app, sem hardware extra.
- ✅ Controle é total: o cliente decide o que a tela mostra, sem latência de casting.
- ⚠️ Precisamos manter um protocolo WS versionado e o canal de auto-update
  (`palco-updates`) para os receivers.
- ❌ Chromecast/AirPlay **não fazem parte** do projeto — não propor, não implementar.
