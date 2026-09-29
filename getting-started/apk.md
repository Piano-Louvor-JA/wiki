# Getting started — mobile app

Repository: [Piano-Louvor-JA/apk](https://github.com/Piano-Louvor-JA/apk)

The Flutter mobile companion is offline-first and must preserve shared API-contract parity with desktop and web.

## Prerequisites

- Flutter SDK compatible with the repository
- A simulator or authorized physical device

## Run locally

```bash
git clone https://github.com/Piano-Louvor-JA/apk.git
cd apk
flutter pub get
flutter run
```

Use `--dart-define` values from the repository's public environment example or your own local service. Do not commit service URLs or secrets into source code.

## Commands

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

## Delivery phases

- `0.1`: read existing content
- `0.2`: edit and organize content
- `0.3`: create custom content
- `1.0`: full supported parity and production readiness

Patch releases are bug fixes only.

## Pitfalls

- Offline content belongs to the application sandbox; account for that during device debugging.
- Physical-device validation may require a human action such as device unlock or approval.
- Do not copy desktop UI code. Implement the same contract in Flutter.

Next: [release workflow](../workflows/releases.md).
