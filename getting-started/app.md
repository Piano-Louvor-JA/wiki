# Getting Started — app (Desktop Electron)

> Repo: [pianolouvorja/app](https://github.com/Piano-Louvor-JA/app) · versão
> atual na linha 1.28.x · Electron + Vue 3 + Vuetify + Pinia + Vite

O **app** é o código-fonte de referência do produto: desktop nativo para
Windows, macOS e Linux. Fork evolutivo do Louvor JA original
([app.louvorja.com.br](https://app.louvorja.com.br/)).

## Pré-requisitos

- Node.js LTS (recomendado 22+)
- npm

## Rodando

```bash
git clone https://github.com/Piano-Louvor-JA/app.git
cd app
npm install
cp .env.example .env.local   # ajuste se quiser usar sua API local/túnel
npm run dev
```

> ⚠️ **Electron desktop NUNCA abre no browser.** Se você rodou e abriu a URL do
> Vite no Chrome, você está testando a coisa errada — a janela Electron é o app.

## Variáveis de ambiente (`.env.local`, não versionado)

| Var | O que faz |
|-----|-----------|
| `VITE_URL_DATABASE` | API de catálogo (json_db) — primária |
| `VITE_URL_FILES` | Base de arquivos (covers, mídias) |
| `VITE_PALCO_API_URL` | API de coletâneas custom + login (`/v1/custom`) |
| `PIANO_API_BASE_URL` | Main process: download de mídia offline (deve espelhar `VITE_PALCO_API_URL`) |
| `VITE_API_FALLBACK_URLS` | Cascata de fallback de APIs, separada por vírgula |

## Scripts principais

| Comando | O que faz |
|---------|-----------|
| `npm run dev` | Dev server + Electron |
| `npm run build` | Type-check + build de produção |
| `npm run test` | Vitest |
| `npm run type-check` | vue-tsc |
| `npm run version:min` / `:bug` | bump minor/patch (conventional, cria tag) |

## Debug

- `ELECTRON_OPEN_DEVTOOLS=1` abre DevTools na inicialização
- CDP disponível na porta `:9222`

## Pitfalls conhecidos

- Arquivos lidos em runtime (EULA, templates) **não podem** estar no
  `.gitignore` — electron-builder respeita `.gitignore` e o arquivo some do asar
  → `ENOENT` e o app não abre (bug real que já aconteceu).
- Nunca usar `window.confirm` — usar `AppConfirm`.
- Features novas precisam de caminho de paridade (ver
  [architecture/overview.md](../architecture/overview.md)).

## Onde continuar

- Workflows de PR: [workflows/git-and-prs.md](../workflows/git-and-prs.md)
- Decisões: [adr/](../adr/README.md)
