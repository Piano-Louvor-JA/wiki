# Índice de Skills (conhecimento de domínio)

> Estas skills vivem na biblioteca de conhecimento do projeto. Aqui
> registramos **o que cada uma cobre**, para que qualquer dev/agente saiba onde
> buscar conhecimento antes de começar uma task. Peça ao agente que carregue a
> skill relevante, ou leia o resumo abaixo.

## Desktop (app Electron)

- **pianolouvorja-app-electron** — arquitetura geral do desktop, DevTools
  (ELECTRON_OPEN_DEVTOOLS, CDP :9222), pitfalls de build.
- **pianolouvorja-app-electron-workflow** — ciclo de trabalho: branch, teste,
  PR, release multi-plataforma.
- **louvorja-module-development** — como criar módulos (liturgia, hinos, bíblia).
- **pianolouvorja-ui-patterns** — design system, botões com borda/fundo
  (texto plano não é botão), AppConfirm em vez de window.confirm.
- **pianolouvorja-stage-customization** — personalização do Palco (StageSettings).
- **palco-multi-screen** / **pianolouvorja-palco-cast** — arquitetura
  multi-tela e cast para TV.

## Web

- **pianolouvorja-web-repo-workflow** — repo, CI, release, PWA.
- **pianolouvorja-web-feature-patterns** — padrões de implementação de features.
- **pianolouvorja-site-patterns** — padrões do site (Nuxt 3).

## Mobile (apk Flutter)

- **pianolouvorja-flutter** — arquitetura, offline-first (`music-offline/` no
  sandbox do app), paridade com desktop.
- **pianolouvorja-mobile-release-workflow** — qualidade, versionamento, PR,
  release (semver por fases: v0.1 leitura, v0.2 escrita, v0.3 criação, v1.0).

## API

- **pianolouvorja-api** — Hono + Zod OpenAPI + SQLite, contratos `_db`,
  rotas `/v1/custom`, sistema de arquivos.
- **louvorja-api** — API oficial do LouvorJA (upstream, api.louvorja.com.br).

## Dados e interoperabilidade

- **louvorja-delphi-interop** — formatos de dados do Delphi original.
- **louvorja-ja-liturgy** — spec do formato `.ja` (liturgia).
- **louvorja-remote-pairing** — pareamento/controle remoto entre dispositivos.
- **wt5-palco-cloud** — TVs/receivers via relay cloud.

## Regras transversais (valem pra tudo)

- Paridade web ↔ app ↔ APK é **obrigatória** (a maioria dos usuários está no celular).
- Testes com vídeo: música SACRA IASD (Athus, Vox, Arautos) — nunca mundana.
- TV conecta ao cliente via **WebSocket próprio** — não existe Chromecast no projeto.
