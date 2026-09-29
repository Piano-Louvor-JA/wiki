# Getting started — desktop app

Repository: [Piano-Louvor-JA/app](https://github.com/Piano-Louvor-JA/app)

The desktop application is the native reference implementation for creation, playback and presentation workflows.

## Prerequisites

- Current Node.js LTS
- npm

## Run locally

```bash
git clone https://github.com/Piano-Louvor-JA/app.git
cd app
npm install
cp .env.example .env.local
npm run dev
```

Use only values you control in `.env.local`; never commit it.

## Common commands

```bash
npm run dev
npm run build
npm run test
npm run type-check
```

Run the scripts actually declared by the repository's `package.json`.

## Pitfalls

- The Electron window is the application. A Vite URL in a browser is not an Electron validation.
- Runtime resources must be included in desktop packaging.
- Preserve API-contract parity with web and mobile when a feature changes shared behavior.
- Use the product confirmation component instead of browser-native blocking dialogs.

Next: [architecture overview](../architecture/overview.md) and [PR workflow](../workflows/git-and-prs.md).
