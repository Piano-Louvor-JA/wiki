# Governance

## Decision Authority

| Domain | Decider | Process |
|--------|---------|---------|
| **Product/Spec** | PO | SPEC.md com RF-ID → APROVAÇÃO obrigatória antes de código |
| **Architecture/Tech Stack** | Tech Lead (Ezequias) + PO | ADR proposto → discussão → decisão registrada |
| **Infrastructure/Deploy/Secrets** | Infra Admin (Ezequias) | Não delegado; execução manual ou via CI/CD admin |
| **UI/UX** | PO + Designer | Mock/Design review → spec → implementação |
| **Release/Versioning** | PO + Release Manager | Semver por fase (v0.1→v1.0) + milestone no GitHub Projects |
| **Quality Gates** | QA Agent (7 Gates) | Obrigatório; override só com evidência + PO |

## Branch Flow (obrigatório)



- PR SEMPRE base 
-  só recebe via PR → (release)
- Nenhuma exceção

## Decision Records

- ADRs em  (decisões arquiteturais)
- Specs em  (rastreabilidade RF-ID)
- Plans em  (fases shippable, tasks atômicas)

## Conflict Resolution

1. Discord direto entre PO + Tech Lead
2. Se impasse: PO decide produto, Tech Lead decide infra
3. Decisão registrada em ADR + comentário na issue/PR
