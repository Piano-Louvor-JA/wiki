# Getting started — web PWA

Repository: [Piano-Louvor-JA/web](https://github.com/Piano-Louvor-JA/web)

The web application runs in the browser and shares visual language and API contracts with the desktop app.

## Prerequisites

- Current Node.js LTS
- npm

## Run locally

```bash
git clone https://github.com/Piano-Louvor-JA/web.git
cd web
npm install
cp .env.example .env.local
npm run dev
```

Never commit `.env.local`.

## Common commands

```bash
npm run dev
npm run build
npm run test
npm run test:e2e
npm run type-check
```

Run only commands present in the checked-out repository.

## Platform boundaries

- Browsers cannot spawn local processes; playback remains browser-native.
- Multi-screen presentation follows the receiver protocol rather than desktop-local display assumptions.
- Keep API fallbacks and error behavior compatible with the shared contract.

Next: [architecture overview](../architecture/overview.md).
