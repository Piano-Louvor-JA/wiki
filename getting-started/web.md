# Getting Started — web (PWA)

> Repo: [pianolouvorja/web](https://github.com/Piano-Louvor-JA/web) · versão
> atual 1.20.x · Vue 3 + Vuetify + Vite + PWA

Aplicação exclusiva para navegador (sem shell Electron). Mesma base visual e
de componentes do desktop (Vuetify, tabler icons, Plus Jakarta Sans).

## Rodando

```bash
git clone https://github.com/Piano-Louvor-JA/web.git
cd web
npm install
cp .env.example .env.local
npm run dev
```

## Variáveis de ambiente

| Var | O que faz |
|-----|-----------|
| `VITE_URL_DATABASE` | API de catálogo — pode apontar para `api.louvorja.com.br` (oficial) ou `api.pianolouvorja.com.br` (piano) |
| `VITE_URL_FILES` | Base de arquivos (covers/mídias) |
| `VITE_API_FALLBACK_URLS` | Cascata de fallback de APIs, separada por vírgula |
| `VITE_APP_MODE` | `development` em dev |

## Scripts

| Comando | O que faz |
|---------|-----------|
| `npm run dev` | Dev server |
| `npm run build` | Type-check + build |
| `npm run test` | Vitest |
| `npm run test:e2e` | Playwright |
| `npm run test:mutation` | Stryker (mutation testing) |
| `npm run type-check` | vue-tsc |

## Diferenças do desktop

- **Sem player externo** (VLC): o sandbox do navegador impede spawn de
  processos — sempre player interno.
- **Sem projeção local multi-monitor**: projeção de palco na web segue a
  arquitetura de receivers (ver [architecture/overview.md](../architecture/overview.md)).
- Cascata de fallback de APIs idêntica à do desktop (`VITE_API_FALLBACK_URLS`).

## Onde continuar

- [workflows/git-and-prs.md](../workflows/git-and-prs.md)
