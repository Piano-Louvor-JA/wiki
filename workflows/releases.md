# Workflows — Releases por repo

## Visão geral

| Repo | Como releasea | Canal |
|------|--------------|-------|
| app (desktop) | `npm version` + tag `vX.Y.Z` + build electron-builder | GitHub Releases + auto-update (electron-updater) |
| web | `npm version` + deploy do build | URL de produção |
| api | PR staging→main + deploy no VPS (Docker) | api.pianolouvorja.com.br |
| apk | tag `vX.Y.Z` + build Flutter | GitHub Releases + auto-update in-app (sem Play Store por enquanto) |
| palco-receiver | build + publish no canal | palco-updates (GitHub Pages) |

## Desktop (app)

1. Merge da release PR (staging→main)
2. `npm run version:min` (ou `:bug`) — commit + tag automáticos
3. Push da tag dispara build multi-plataforma
4. Auto-update: usuários recebem via electron-updater

## Mobile (apk) — semver por fases

| Tag | Fase |
|-----|------|
| `v0.1.x` | Leitura (concluída) |
| `v0.2.x` | Escrita |
| `v0.3.x` | Criação de conteúdo custom (atual) |
| `v1.0.x` | Paridade total + produção |

- Patch = **só** correção de bugs.
- O APK verifica atualização via GitHub Releases API e instala o APK direto
  (update in-app, sem loja).
- Fases são curtas e validadas (device real, pelo time) antes de empilhar.

## API

1. Merge staging→main (PR de release)
2. Deploy no VPS: container Docker reinicia e roda migrations no boot
3. **Pós-deploy obrigatório**: verificar `/v1/health` (200) e conferir que as
   migrations rodaram completas (502 por ~30-60s no restart é normal;
   persistindo >2min, investigar log do container)
4. Validar endpoint novo/alterado por fora (curl) antes de avisar o time

## palco-receiver (TVs)

Receivers checam o canal `palco-updates` (GitHub Pages) e se atualizam
sozinhos. Publicar lá = fazer rollout para todas as TVs conectadas.
