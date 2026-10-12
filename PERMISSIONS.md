# Permissões — o que um contribuidor consegue (e o que precisa de admin)

> Contribuidores (write) NÃO têm acesso admin. Este documento lista o que
> você resolve sozinho e o que é bloqueado até um admin (Ezequias) agir.

## ✅ Você resolve sozinho (write access)

| Ação | Como |
|------|------|
| Clonar, branch, commit, push | `git` normal |
| Abrir PR (base `staging`) | `gh pr create` ou UI |
| Criar/editar issues | `gh issue create` + templates |
| Criar labels, milestones (em repos com permissão) | `gh label` / `gh api repos/.../milestones` |
| Rodar CI, ler logs de Actions | `gh run watch` / UI |
| Criar branches novas | `git checkout -b feat/...` |
| Comentar/revisar PRs de outros | UI ou `gh pr review --comment` |

## ⛔ Bloqueado — requer admin (abrir issue e aguardar)

| Ação | Por quê | Como pedir |
|------|---------|-----------|
| **Merge de PR** | Branch protection exige review admin | Peça review direto ao Ezequias na PR |
| **Editar Settings do repo** (pages, secrets, webhooks, rulesets) | Admin only | Issue com label `needs-admin` |
| **Criar/editar GitHub Projects v2 da org** | Project admin | Issue descrevendo campos/views desejados |
| **Upload de social preview** | Sem API pública; UI admin | Envie a imagem (1280×640) + repo na issue |
| **Mudar visibilidade de repo/project** | Admin only | Issue + justificativa |
| **Gerenciar colaboradores/teams** | Admin only | Issue com @ do novo membro |
| **Secrets de CI/CD** | Admin only | Issue com nome da variável (NUNCA o valor no issue) |
| **Deploy de produção** (VPS/Firebase) | Acesso de infra é do admin | Procedimento em cada getting-started; admin executa |

## 🔄 Fluxo quando algo precisa de admin

1. Abra issue com label `needs-admin` + título claro (`[Admin] <o que precisa>`)
2. Descreva: o quê, por quê, urgência (P0-P3)
3. Se for bloqueio de PR: marque a PR como draft até o admin agir
4. SLA informal: blockers de release tratados primeiro

## 💡 Dicas pra não travar

- **Sua PR não mergeia?** Não é bug — branch protection. Marque o Ezequias (`@ezequiasfonseca`) num comentário.
- **Precisa de env var nova em CI?** Abra a issue; o admin adiciona o secret e responde na issue.
- **Wiki/Projects:** se falta algo nessa wiki, PRs são bem-vindas — contribuidor tem write aqui.
