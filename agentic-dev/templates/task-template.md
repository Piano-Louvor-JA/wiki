# Template de TASK (para implementer)

> Passar 1 task do PLAN.md para um subagente/implementer. Fonte: skill
> subagent-driven-development.

```markdown
## Task: <F1-T1 — título>

**Arquivos:** caminhos exatos a criar/modificar
**Approach:** passos concretos (da spec/plan)
**Teste:** comando que deve passar (TDD: RED → GREEN)
**Commit:** `feat: <mensagem>`

Regras:
- Seguir convenções de AGENTS.md do repo
- NÃO tocar em arquivos fora do escopo da task
- NÃO commitar reformatting pré-existente
- Se bloqueado (decisão pendente), PARAR e reportar, não assumir
```
