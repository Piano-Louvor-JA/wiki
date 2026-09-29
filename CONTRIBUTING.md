# Workflows — Git, Branches e PRs

## Fluxo de branches (obrigatório — vale para TODOS os repos, incluindo docs)

```
feat/* ──PR──► staging ──PR──► main
```

- **PRs SEMPRE base `staging`** (nunca direto na `main`).
- `main` só recebe PR **de** `staging` (release/publicação).
- Nenhuma exceção — inclusive neste repo (docs).

## Antes de abrir PR (checklist)

1. `git log --oneline origin/staging..HEAD` — só os seus commits na branch
2. Lint + typecheck + testes + build locais **passando**
3. Commits atômicos e convencionais (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`)
4. **Nunca** incluir reformatting de código pré-existente em commit de feature
5. **Nunca** `git checkout -- .` sem revisar `git status` antes
6. Sem segredos/IPs/paths de produção no diff

## Review

- **Ezequias revisa antes do merge** (padrão do time).
- PR pequena e focada > PR grande. Uma feature = uma PR.
- Responder feedback do reviewer em < 24h, sem discutir estilo.

## Convenções de mensagem

```
feat(scope): descrição curta no imperativo
fix(scope): correção
docs: mudança de documentação
chore(release): versão X.Y.Z   ← gerado pelo npm version
```

Versões são bumpadas pelos scripts `npm run version:min` / `version:bug`
(criam commit + tag automáticos).

## Trabalhando com agentes de IA

Agentes seguem SDD: spec aprovada → plan → tasks → implement → verify.
Ver [agentic-dev/index.md](../agentic-dev/index.md). Regras de ouro para agentes:

- Ler o `AGENTS.md` do repo **antes** de tocar em código
- TDD real (testar o código de verdade, não "testes falsos" que quebram a
  função propositalmente e mesmo assim passam)
- Se uma decisão depende de humano (conta de store, senha, credencial) —
  **parar e perguntar**, nunca inventar
- Ao fim de todo ciclo: commitar + pushar; confirmar em qual branch antes
