# Template de SPEC

> Copie para `.planning/<feature>/SPEC.md` no repo do projeto. Fonte: skill
> spec-driven-development (Hermes). Spec é o contrato — código só começa depois
> da spec aprovada.

```markdown
# SPEC: <Nome da Feature>

## Contexto
2-3 frases: por que isso existe, que problema resolve.

## Estado Atual (Baseline)
O que JÁ existe (arquivos, rotas, schemas, testes). Verificar no mundo real,
não confiar em checkmarks de docs antigos.

## Requisitos Funcionais
### RF-01: <Nome>
**User Story:** Como [ator], quero [ação], para [valor].
**Critérios de Aceite (EARS):**
- WHEN [condição] THE SYSTEM SHALL [comportamento]
- IF [condição] THEN THE SYSTEM SHALL [comportamento]

## Requisitos Não-Funcionais
- Performance: <alvo mensurável>
- Segurança: <auth, validação>
- Paridade: <web / app / apk — onde precisa funcionar>

## Decisões Bloqueadas (BD-XX)
| ID | Decisão | Impacto | Quem decide |
|----|---------|---------|-------------|
| BD-01 | | | |

## Fora de Escopo
- <explícito: o que NÃO será feito>

## Dependências
- <libs, APIs, infra>
```
