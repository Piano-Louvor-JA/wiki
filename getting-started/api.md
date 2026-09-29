# Getting started — API

Repository: [Piano-Louvor-JA/api](https://github.com/Piano-Louvor-JA/api)

The API owns shared, versioned contracts consumed by desktop, web and mobile clients.

## Prerequisites

- Current Node.js LTS
- npm

## Run locally

```bash
git clone https://github.com/Piano-Louvor-JA/api.git
cd api
npm install
cp .env.example .env
npm run dev
```

Never commit `.env`. Use local values only.

## Common commands

```bash
npm run dev
npm run build
npm run test
npm run lint
npm run validate:pr
```

Check `package.json` for the exact commands available on the branch.

## Contract and migration rules

- Treat OpenAPI and tested endpoint behavior as shared client contracts.
- For breaking changes, plan compatibility and consumer migration before implementation.
- Write migrations to be safe when rerun where the database tooling supports it.
- After a release, verify health and the intended schema; deployment completion is not proof of migration completion.

Next: [ADR-003](../adr/003-migrations-idempotentes.md) and [release workflow](../workflows/releases.md).
