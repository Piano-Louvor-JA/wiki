# Getting Started — apk (Mobile Flutter)

> Repo: [pianolouvorja/apk](https://github.com/Piano-Louvor-JA/apk) · versão
> atual 0.1.x+20 · Flutter 3.32+ / Dart 3.8+ · flutter_bloc + go_router + Dio

App mobile (Android API21+ / iOS 13+) — companheiro do desktop. **Offline-first**
com download sob demanda. Clean Architecture em camadas.

## Rodando

```bash
git clone https://github.com/Piano-Louvor-JA/apk.git
cd apk
flutter pub get
flutter run
```

## Configuração da API via `--dart-define`

As URLs são gravadas no binário em compile-time — **não há como trocar sem
rebuild**:

| Dart define | O que é |
|-------------|---------|
| `LOUVORJA_URL_DATABASE` | base do catálogo (json_db) |
| `LOUVORJA_URL_FILES` | base de arquivos (covers/MP3) |
| `LOUVORJA_FALLBACK_URLS` | cascata de fallbacks, separada por vírgula |

```bash
flutter run \
  --dart-define=LOUVORJA_URL_DATABASE=https://api.pianolouvorja.com.br/json_db \
  --dart-define=LOUVORJA_URL_FILES=https://api.pianolouvorja.com.br/file
```

## Stack

| Camada | Tecnologia |
|--------|-----------|
| State | flutter_bloc |
| Routing | go_router |
| Networking | Dio (retry + rate-limit) |
| Audio | audioplayers (nativo) / AudioElement (web) |
| i18n | easy_localization (pt-BR, en, es) |
| Ícones | tabler_icons_plus (mesma lib do Electron/web) |
| Auto-update | GitHub Releases API + OpenFilex |

## Funcionalidades por fase (semver por fases)

| Versão | Escopo |
|--------|--------|
| **v0.1** | Leitura (hinos, bíblia, liturgia, timer) ✅ |
| **v0.2** | Escrita (edição/organização de culto no celular) |
| **v0.3** | Criação de conteúdo custom (paridade com desktop) ← atual |
| **v1.0** | Paridade total + produção |

## Debug em device real

Downloads offline ficam no sandbox privado do app
(`getApplicationDocumentsDirectory()/music-offline`) — invisível sem root.
Para inspecionar: `adb` em build debug, ou logcat (`flutter logs`) que mostra
a causa real de erros de playback (stack trace, não o erro genérico).

Testes de device (PIN bloqueia automação) são feitos manualmente pelo time.

## Onde continuar

- Release workflow: [workflows/releases.md](../workflows/releases.md)
