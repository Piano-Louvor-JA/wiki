# Template de PLAN

> Copie para `.planning/<feature>/PLAN.md`. Fonte: skill writing-plans.
> Cada task = 1 commit atômico, 2-5 min de execução.

```markdown
# PLAN: <Feature>

> Fonte: .planning/<feature>/SPEC.md

## FASE 1 — <Nome>

- [ ] **F1-T1** <o que fazer, arquivos exatos, comando de verificação, msg de commit>
- [ ] **F1-T2** ...

## Definition of Done (por fase)
- [ ] <critério verificável>
```

Regras:
1. Task nunca cruza 2 commits.
2. Cada task tem caminho de arquivo exato e como verificar (teste/comando).
3. Fase é "shippable" — pode parar entre fases.
4. Tasks bloqueadas por BD-XX da SPEC ficam marcadas `[BLOQUEADO BD-01]`.
