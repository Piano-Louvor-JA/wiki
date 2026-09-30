# Regression Gate 4-Layer

> **Metodologia pública** — 4-layer regression gate implementation. Aplica-se a qualquer stack.

---
> **Objetivo**: Nenhuma mudança piora o estado de staging sem ser detectada e bloqueada antes do merge.

## Camada 1 — Pre-commit (local, <5s)

```bash
# app/web/api
npm run lint          # eslint/biome
npm run typecheck     # vue-tsc/tsc
# flutter
# flutter analyze --fatal-warnings --no-fatal-infos
```

Detecta: erros de sintaxe, type, lint óbvios.

## Camada 2 — Pre-push (local, antes do push)

### Repos Node (app/web/api)
```bash
npm run test:regression -- --compare
```

### Flutter
```bash
dart run scripts/test-regression.dart --compare
```

Detecta: regressão de testes ou analyze vs baseline de staging.

## Camada 3 — CI (GitHub Actions)

Job `regression-gate`:
```yaml
regression-gate:
  name: Regression Gate
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v7
      with: { fetch-depth: 0 }
    - uses: subosito/flutter-action@v2   # flutter only
      with: { channel: stable, cache: true }
    - run: flutter pub get                 # flutter only
    - run: npm ci                          # node only
    - name: Baseline (staging)
      run: |
        git stash -u || true
        git checkout staging
        [ -f scripts/test-regression.* ] && { 
          [ -x scripts/test-regression.sh ] && chmod +x scripts/test-regression.sh
          [ -f scripts/test-regression.mjs ] && node scripts/test-regression.mjs --baseline
          [ -f scripts/test-regression.dart ] && dart run scripts/test-regression.dart --baseline
        }
        git checkout ${{ github.head_ref }}
        git stash pop || true
    - name: Compare (PR branch)
      run: |
        [ -f scripts/test-regression.mjs ] && node scripts/test-regression.mjs --compare
        [ -f scripts/test-regression.dart ] && dart run scripts/test-regression.dart --compare
```

Falha se: testes passed ↓ ou failed ↑ ou analyze OK → FAIL.

## Camada 4 — Branch Protection (GitHub Settings)

Requisitos da branch `staging`:
- [x] Pull request reviews obrigatórios (Ezequias)
- [x] Status checks obrigatórios: `regression-gate`, `lint`, `typecheck`, `test`, `build`
- [x] Requer branches atualizadas
- [ ] Permitir force pushes
- [ ] Permitir exclusões


## Pitfalls
- **Pular regression gate local** → push de código que já quebrará no CI (perde tempo)
- **Esquecer fetch staging** → hook compara com baseline antigo (falso positivo/negativo)
- **Branch base main** → viola política feat→staging→main
- **PR sem evidência de regressão** → revisão obriga preenchimento do template

---

## Exceções Conhecidas

- Testes pré-existentes quebrados em staging entram no baseline (não bloqueiam novo push se não piorarem)
- Warnings/info do analyze são ignorados (apenas --fatal-warnings bloqueiam)

---

## Skills Relacionadas

`agentic-dev-rules`, `test-driven-development`, `vitest-coverage-workflow`, `stryker-mutation-testing`, `spec-driven-development`, `project-excellence`

---

## Checklist Rápido

```markdown
- [ ] Branch feat/* base staging?
- [ ] Pre-commit OK (lint/typecheck)?
- [ ] Pre-push regression gate OK?
- [ ] PR base staging + template?
- [ ] CI regression-gate success?
- [ ] Review Ezequias?
```
