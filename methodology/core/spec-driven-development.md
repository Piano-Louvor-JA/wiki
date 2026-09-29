# Spec-Driven Development

> **Metodologia pública** — SPEC → PLAN → Tasks → Verify (EARS, BD-XX, rastreabilidade RF-ID). Aplica-se a qualquer stack.

---
## O Que É

Workflow de desenvolvimento onde a **especificação** (spec) é o contrato. Código só começa depois da spec aprovada. Tudo é verificado contra a spec, não contra "parece que funciona".

**Princípio core:** Spec é fonte da verdade. Se não tá na spec, não existe. Se tá na spec, tem que estar no código.

## Entry Point: project-excellence

**SDD é carregado implicitamente quando `project-excellence` é ativado.** Não é uma skill separada que você precisa lembrar de chamar — é o pipeline padrão. O `project-excellence` mapeia cada fase do seu workflow (MAPEAR → OBSIDIAN → ESPECIFICAR → IMPLEMENTAR → RELEASE) para as skills SDD correspondentes.

Quando quiser SDD puro (sem o peso do PE), carregue esta skill diretamente. Caso contrário, só ative `project-excellence` e o fluxo completo dispara.

## Regra de Ouro: Verificar Escopo ANTES de Escrever

**SEMPRE verificar o escopo com o usuário se o prompt original for ambíguo ou puder ser interpretado de múltiplas formas.**

Não assuma que você entendeu — o usuário pode estar pensando em algo completamente diferente do que você inferiu. Uma SPEC no tópico errado é pior que nenhuma: gasta tempo, frustra o usuário, e exige descarte.

### Gatilhos para verificar escopo:
- Prompt vago ou genérico ("documenta isso", "cria spec disso", "quero um plano")
- Prompt que menciona algo que o usuário já tem (ex: "não era pra vendas, eu já tenho um CRM")
- Prompt com múltiplas interpretações possíveis
- Informações conflitantes ou incompletas
- Contexto histórico (summary/session_search) que pode estar enviesando a interpretação

### Como verificar:
1. **Pergunte de forma direta e concisa** — 1 pergunta só. Não faça 3 perguntas. O usuário responde 1 de cada vez.
2. **Confirme antes de escrever** — se houver chance de estar no tópico errado, confirme com 1 frase antes de abrir SPEC.md.
3. **Nunca produza 4 arquivos no tópico errado** por falta de verificação. O custo de 1 pergunta de 10 palavras é baixo; o custo de reescrever 800+ linhas é alto.

### Caso real (learned 2026-07-02):
Usuário pediu: "documenta usa spec driven development adaptado e também usa o project excellence".
O contexto histórico falava de prospecção em grupos Telegram, então assumi que era sobre marketing/vendas.
Usuário corrigiu: "não era bem isso, não era pro quesito de vendas, eu tenho inclusive um crm também".
**Lição:** Havia múltiplas interpretações possíveis. Deveria ter perguntado "Qual parte do projeto? Vendas ou outra coisa?" antes de escrever os 4 documentos.

## Quando Usar

- Feature com 3+ tasks ou múltiplos arquivos
- Trabalho delegado a subagentes (AI ou humano)
- Features que precisam de rastreabilidade (produção, open-source)
- Quando você quer qualidade reproduzível
- **Roadmap multi-fase** — quando o usuário quer "atacar tudo", consolidar FASES 3-6 em uma mega-SPEC e PLAN único, implementando fase a fase (cada fase é "shippable" independentemente)
- **Documentação de domínio existente** — quando o usuário pede "documenta X" (seja sistema, fluxo, arquitetura ou processo) e X é algo que existe ou está sendo construído
- **Revisão de PRs existentes** — quando o usuário diz "usa project-excellence/oss-excellence" num contexto de fixes, aplica o mesmo rigor. Ler a spec do repo (AGENTS.md/CONTRIBUTING.md) ANTES de corrigir qualquer coisa. Spec é a fonte da verdade do reviewer — se você não lê, corrige errado.

**Não usar para:** hotfix de 1 linha, spike experimental, refactor trivial.

## Multi-Phase Mega-Spec Pattern

Quando o usuário pede para atacar múltiplas fases de um roadmap de uma vez:

0. **Reality Check (OBRIGATÓRIO quando docs existentes marcam items como [x])** — Se existem PLAN.md/AGENTS.md/SPEC.md anteriores com checkmarks `[x]`, NÃO confie. Verifique no mundo real se os items realmente existem (DB schemas, arquivos, testes, processos rodando). Docs mentem mais frequentemente que código. Se descobrir que items marcados [x] não existem, reportar ao usuario como "docs vs reality gap" ANTES de escrever a nova spec.
1. **BaselineAudit FIRST** — Mapeie exatamente o que existe (rotas, componentes, hooks, testes, dependências, schemas DB) ANTES de escrever a SPEC. Sem isso, você re-especifica trabalho já feito ou re-especifica algo que nunca foi feito. Use `find src/ -name "*.tsx"`, `cat package.json` (deps), `grep -r "sonner|driver" src/`, `SELECT * FROM information_schema.schemata WHERE schema_name = 'xxx'`, etc. **Ver `references/baseline-audit-checklist.md` para a técnica batched via execute_code (12-15 comandos em 1 chamada, resultados estruturados em ~5s).**
2. **Uma SPEC.md consolidada** — Todos os RFs de todas as FASES em um único arquivo, com seções claras por fase (`## FASE 3: ...`, `## FASE 4: ...`, etc). Inclua seção "Estado Atual (Baseline)" mapeando o que já existe vs o que falta.
3. **Um PLAN.md consolidado** — Todas as tasks bite-sized de todas as FASES, organizadas por sub-fase (F1-T1, F1-T2... F8-T3). Inclua estimativa de tempo por fase e total.
4. **Definição de Done por FASE** — Cada fase tem seu próprio checklist de "Definition of Done" para que possa ser "shippada" independentemente.
5. **Parallel Subagent Dispatch — USE COM CUIDADO** — SPEC.md, PLAN.md, AGENTS.md e CONTEXT.md PODEM ser escritos em paralelo via `delegate_task`, MAS apenas se o contexto por subagente for < 3KB de instrucoes + dados resumidos. NAO enviar baseline audit completo (schemas, file listings, 9 docs Obsidian) como contexto de subagente — vai causar 413.
   **RECOMENDACAO:** Para Mega-Spec, escrever os 4 arquivos voce mesmo com `write_file`. Mais rapido, mais confiavel, sem risco de payload. Usar subagentes apenas para pesquisas paralelas (ex: 3 subagentes coletando dados de fontes diferentes).
   **Se insistir em subagentes:** Contexto por subagente < 50 linhas. Detectar falha: `wc -l` nos 4 arquivos apos dispatch — se counts forem iguais ao pre-dispatch, os writes nao aconteceram. Fallback: escrever direto.
6. **Implementar fase a fase** — NÃO tente implementar tudo de uma vez. Execute FASE 1 completa → verify → ship → FASE 2 → etc.

**Pitfall:** Sem o BaselineAudit, você escreve RFs para coisas que já existem (ex: "adicionar toasts" quando sonner já está no layout). O audit previne esse desperdício e também alimenta a seção "Estado Atual (Baseline)" da SPEC.

**Pitfall:** Sem o Reality Check, você herda claims falsos de docs anteriores ("schema CRM criado" quando nunca foi). Sempre verificar com ferramentas reais, nunca confiar em checkmarks `[x]`.

**Concrete Reality Check technique (proven 2026-07-13 on Jornada no Deserto):**
When a PLAN has 24+ tasks, use batched `find`/`test -f`/`grep -c` to verify each task in seconds:
```bash
# Check if files/dirs exist for each planned task
for f in Board3D PlayerPiece3D CardDeck3D; do
  test -f "src/components/three/${f}.tsx" && echo "EXISTS: $f" || echo "MISSING: $f"
done
# Check for specific patterns (e.g., rapier integration claimed but absent)
grep -c "rapier\|RigidBody" src/components/three/Dice3D.tsx
# Line count to distinguish stubs from real implementations
wc -l src/components/three/houses/ThematicHouses.tsx  # 301 lines = real, 15 lines = stub
```
Also verify **naming convention gaps** — PLAN may say `PlayerSetup` but actual file is `SetupScreen.tsx`. Map PLAN names to real file names before declaring something DONE or PENDING. Discovered 8 naming mismatches in PLAN.v2.

## Specs com Criterios de Aceite para Issues/PRs

**Quando o usuario pede specs antes de criar issues** (ex: "quais vao ser os criterios de aceite pras issues serem mergeadas"), cada spec deve conter:

1. **Descricao detalhada** — o que precisa ser feito, incluindo arquivos afetados e codigo de referencia
2. **Como testar** — passos manuais concretos para verificar a funcionalidade
3. **Criterios de aceite** — checkbox explícitos que definem quando a issue pode ser mergeada
4. **Arquitetura esperada** (para features novas) — estrutura de arquivos/diretorios

**NUNCA pular specs e ir direto para issues quando o usuario pede specs.** Se o usuario pede specs, specs sao o deliverable. Issues vêm depois, só apos specs aprovadas.

## Multi-Endpoint Spec Pattern (Roadmap já mapeado)

Quando o usuário já tem um roadmap/plano multi-endpoint (ex: PLAN.md com tasks F1-T1 até F5-T3) e pede specs para os endpoints planejados:

1. **Uma spec por endpoint** — NÃO uma mega-spec consolidada. Cada endpoint = 1 arquivo de spec independente.
2. **Traceabilidade por RF-ID** — Cada spec referencia o ID da task no plano mestre (ex: `RF-ID: F2-T1 (PLAN.md)`).
3. **Diretório dedicado** — Salvar em `.planning/specs/` com nomenclatura `{RF-ID}-{kebab-name}.md` (ex: `F2-T1-categories-albums.md`).
4. **README índice** — Criar `.planning/specs/README.md` com tabela consolidada (RF-ID, endpoint, complexidade, dependências) e ordem de implementação sugerida respeitando dependências.
5. **Specs-only deliverable** — Quando o usuário pede apenas specs (confirmar intenção), o entregável são os arquivos de spec + README. PRs por endpoint vêm depois.

**Vantagens sobre mega-spec:**
- Cada spec vira 1 PR isolada (diff pequeno, review rápido)
- Dependências entre endpoints ficam explícitas (ex: F2-T2 depende de F2-T1)
- Implementação incremental sem bloquear o todo
- Reuso de specs como critério de aceite da PR correspondente

**Pitfall:** Antes de escrever specs, sempre fazer baseline audit — comparar rotas existentes (`routes/web.php`, controllers) com o plano para identificar quais endpoints JÁ existem vs quais faltam. Escrever spec para endpoint já implementado é desperdício.

## Planning-Only Mode

When the user signals "só planejar" or equivalent, the SDD cycle stops after SPECIFY + PLAN. The deliverable is 4 files (no implementation):

1. **SPEC.md** — Requirements specification with baseline audit
2. **PLAN.md** — Bite-sized tasks with file paths, commit messages, estimates
3. **AGENTS.md** — Agent guidance (stack, conventions, pitfalls, what NOT to do)
4. **CONTEXT.md** — Technical context (env vars, API endpoints, SQL setup, design specs)

Save to `.planning/<feature-name>/` in the project repo. Always confirm intent before proceeding to implementation. Templates: `references/spec-template.md` e `references/context-template.md`.

**When used with AI features (LLM/RAG/fine-tuning):** The BASELINE AUDIT is critical — map existing infra (LLM APIs, embedding models, vector DB availability, GPU/no-GPU) BEFORE writing the spec. This prevents specifying fine-tuning on a machine with no GPU, or RAG with an unavailable vector DB extension. See `llm-integration-patterns` for NVIDIA NIM API details and pgvector patterns.

## As 4 Fases

```
SPECIFY → PLAN → IMPLEMENT → VERIFY
   ↑__________________________|
         (se spec divergir, volta)
```

### Fase 1: SPECIFY (Spec Architect)

**Quem:** Subagent leaf com modelo de alto ranking, ou você mesmo.

**Output:** `SPEC.md` na raiz do projeto (ou `.hermes/specs/`).

```markdown
# SPEC: [Nome da Feature]

## Contexto
[2-3 frases: por que isso existe, que problema resolve]

## Requisitos Funcionais
### RF-01: [Nome]
**User Story:** Como [ator], quero [ação], para [valor].
**Critérios de Aceite (EARS):**
- WHEN [condição] THE SYSTEM SHALL [comportamento]
- IF [condição] THEN THE SYSTEM SHALL [comportamento]

## Requisitos Não-Funcionais
- Performance: [latência alvo, throughput]
- Segurança: [autenticação, autorização necessária]
- Acessibilidade: WCAG 2.1 AA

## Fora de Escopo
- [Explicitamente o que NÃO será feito nesta iteração]

## Dependências
- [libs, APIs, infraestrutura necessária]
```

**Formatos de critério de aceite:**
- **EARS** (Easy Approach to Requirements Syntax): `WHEN/IF/WHILE/ONCE [trigger] THE SYSTEM SHALL [response]`
- **BDD** (Given/When/Then): `Given [contexto], When [ação], Then [resultado]`

### Fase 2: PLAN (Planner)

**Quem:** Skill `writing-plans`.

**Output:** `PLAN.md` com tasks bite-sized (2-5 min cada).

Usar a skill `writing-plans` diretamente. Cada task deve ter:
- Arquivos a criar/modificar (caminho exato)
- Código completo ou pseudocódigo detalhado
- Comando de teste para verificar
- Mensagem de commit

### Fase 3: IMPLEMENT (Implementer)

**Quem:** Skill `subagent-driven-development`.

Para cada task do plano:
1. Dispatch implementer subagent (fresh context)
2. Implementer segue TDD: teste falha → código → teste passa
3. Commit por task

**Mapeamento de modelo por tipo de task:**
| Tipo de Task | Modelo Recomendado | Por quê |
|-------------|-------------------|---------|
| Spec writing | Modelo mais capaz (alto ranking) | Precisa raciocínio abstrato |
| Plan breakdown | Modelo mais capaz | Decomposição requer visão sistêmica |
| Implementação simples | Modelo rápido (Groq/Cerebras) | Tasks isoladas, bem definidas |
| Implementação complexa | Modelo capaz | Múltiplas interações |
| Code review | Modelo diferente do implementer | Evita viés de confirmação |
| Debug | Modelo capaz + ferramentas | Root cause analysis |

### Fase 4: VERIFY (Reviewer/QA)

**Quem:** Skill `requesting-code-review` + spec compliance check.

Two-stage review:
1. **Spec Compliance:** O código faz o que a spec pede? Todos os RF atendidos?
2. **Quality:** Testes passam? Coverage ok? Lighthouse/SEO ok? LGPD ok?
3. **Regressão (Regression Guard):** suíte dos consumidores mapeados na fase SPECIFY roda verde com evidência. Cada RF que toca código existente tem sua regressão verificada ponta-a-ponta.

## Taxonomia de Papéis

### Papéis Humanos

| Papel | Responsabilidade | No Hermes |
|-------|-----------------|-----------|
| **PO/PM** | Dono da spec. Traduz negócio → critérios de aceite. Aprova antes do código. | Você (o PO) |
| **Designer** | Tokens de design (espaçamento, cor, tipografia) entram na spec. UI é checada contra eles. | Skill `design-md` |
| **Developer** | Orquestra subagentes, revisa output, merge. Em SDD vira mais "orquestração e revisão". | Hermes main agent |
| **QA/Reviewer** | Valida contra spec, não só "funciona". | Skill `requesting-code-review` |
| **SRE** | Controla acesso a ambientes (produção). Gatilhos de deploy/release. | Skills `platform-deploy`, `dokploy` |

### Papéis de Agentes (delegate_task)

| Papel SDD | Hermes delegate_task | toolsets | Modelo |
|-----------|--------------------|----------|---------|
| **Spec Architect** | `delegate_task(goal='Write SPEC.md...', role='leaf')` | `['terminal', 'file', 'web']` | Alto ranking |
| **Planner** | `delegate_task(goal='Break SPEC into tasks...', role='leaf')` → skill `writing-plans` | `['terminal', 'file']` | Alto ranking |
| **Implementer** | `delegate_task(goal='Implement task N...', role='leaf')` → skill `subagent-driven-development` | `['terminal', 'file', 'coding']` | Rápido pra simples, capaz pra complexo |
| **Reviewer** | `delegate_task(goal='Review against spec...', role='leaf')` → skill `requesting-code-review` | `['terminal', 'file', 'web']` | Diferente do implementer |
| **Orchestrator** | Hermes main agent (este processo) — decide qual agente, qual modelo, quando | — | — |

### Convergência dos Frameworks

O padrão **Architect → Implementer → Verifier** aparece em:
- **GitHub Spec Kit**: specify → plan → tasks → implement
- **AWS Kiro**: spec → hooks → implement → verify
- **BMAD**: Architect/PM/QA/Dev (mesma estrutura, nomes diferentes)
- **GSD (Get Shit Done)**: /gsd-spec → /gsd-plan → /gsd-tasks → /gsd-implement
- **Codex/AGENTS.md**: instructions → implementation → review

Todos convergem no mesmo loop de 4 fases. A skill é agnóstica de framework.

## Workflow Completo (Exemplo Prático)

```python
# 1. SPECIFY — Spec Architect subagent
spec = delegate_task(
    goal="Write SPEC.md for: [feature description]. Interview the user if needed.",
    toolsets=['terminal', 'file', 'web'],
    context="Project: [name]. Stack: [tech]. User wants: [description]."
)
# → Output: SPEC.md aprovado pelo PO (o PO)

# 2. PLAN — Planner subagent
plan = delegate_task(
    goal="Read SPEC.md and create PLAN.md with bite-sized tasks.",
    toolsets=['terminal', 'file'],
    context="Use writing-plans skill format. TDD for every task."
)
# → Output: PLAN.md com 10-30 tasks

# 3. IMPLEMENT — Implementer subagents (1 per task)
for task in plan.tasks:
    impl = delegate_task(
        goal=f"Implement: {task.title}",
        toolsets=['terminal', 'file', 'coding'],
        context=f"Task details: {task.full_text}\nFollow TDD strictly."
    )

# 4. VERIFY — Reviewer subagent (different model!)
review = delegate_task(
    goal="Review ALL changes against SPEC.md. Report divergences.",
    toolsets=['terminal', 'file', 'web'],
    context="SPEC: [spec_path]. Changed files: [list]. Check every RF."
)
# → Se divergência: volta pra Fase 3 com correção
# → Se OK: merge + deploy
```

## Templates

### SPEC.md Template

Ver `references/spec-template.md`.

### AGENTS.md Template

Arquivo na raiz do projeto que diz aos agentes de IA:
- Stack e versões exatas
- Convenções de código (Biome, ESLint, etc)
- Como rodar testes
- Estrutura de diretórios
- O que NÃO fazer (pitfalls)

Ver `project-excellence/templates/agents-md-template.md`.

## Cross-Platform Port Spec Pattern

When planning a NEW version of an EXISTING app in a different platform/language
(e.g., Electron+Vue → Flutter, React → React Native, Rails → Next.js):

### Steps
1. **Clone + analyze source app** — read router, modules, stores, IPC handlers,
   package.json. Map every feature/module and its complexity (line count).
2. **Feature include/exclude table** — for each source module, decide:
   - **INCLUDE** (port to new platform, which phase)
   - **EXCLUDE** (platform limitation — projection, multi-monitor, FTP)
   - **DEFER** (v2 — nice to have but not blocking v1)
3. **Entity mapping** — map source types to target types:
   - TS interfaces → Dart `freezed` classes
   - Pinia stores → BLoC patterns
   - Vue components → Flutter widgets
4. **Design system mapping** — port colors, typography, component style:
   - CSS custom properties → ThemeData tokens
   - Vue design components → Flutter custom widgets
   - Same fonts, same palette, same visual language
5. **External dependency audit** — list blockers that need human confirmation:
   - API endpoints (do they exist? are they mobile-friendly?)
   - Developer accounts (Apple $99/yr, Google $25)
   - Credentials, licensing, brand authorization
6. **Blocked decisions table** in AGENTS.md — numbered list with status:pending,
   so AI agents STOP and ask instead of assuming.

### Deliverables (5 files, not the usual 4)
1. **SPEC.md** — RFs adapted to new platform (no desktop-only features)
2. **PLAN.md** — phases with cross-platform-specific tasks
3. **AGENTS.md** — conventions for target stack + blocked decisions table
4. **CONTEXT.md** — full source app analysis + entity/design/feature mapping
5. **README.md** — overview + comparison table (desktop vs mobile feature matrix)

### Key difference from Mega-Spec
Mega-Spec plans multiple phases of the SAME project. Cross-Platform Port
plans a NEW project derived from an EXISTING one — the analysis phase is
heavier (read entire source codebase) and the mapping phase is unique
(types, components, APIs all change).

## Integration with the o PO workflow

**Mandatory regression phase (Regression Guard, 27/09):** between SPECIFY and IMPLEMENT (and again in VERIFY), run the impact matrix from `software-development/regression-guard`: who consumes what will change. Every RF-XXX that touches existing code must list its consumers, and each consumer becomes a regression criterion in the acceptance criteria. Spec without consumer mapping for RFs that touch existing code = incomplete spec, returns to SPECIFY.

## Triple Framework Planning Pattern (PE + OSS Excellence + SDD)

**Trigger:** User pede "liga o project excellence, o oss excellence e o spec driven development para planejar" ou similar — quer planejamento que combine os três frameworks.

**O que cada framework contribui:**
- **Project Excellence (PE):** Quality gates, CI/CD, testing pirâmide, OWASP, DORA, error budget. É o guarda-chuva — governa COMO o projeto opera.
- **OSS Excellence:** LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, issue/PR templates, SECURITY.md, FUNDING.yml, changelog. Governa COMO o projeto se apresenta ao público OSS.
- **SDD:** SPECIFY → PLAN → IMPLEMENT → VERIFY. É o motor de execução de cada feature.

**Como integrar (não justapor):**

1. **Carregar as três skills primeiro** — Antes de qualquer coisa. Atenção ao pitfall #11: `project-excellence` pode ter nome ambíguo; usar path completo `software-development/project-excellence`.
2. **Baseline audit do repo** — Mapear tanto o código (PE/SDD) quanto os artefatos OSS (LICENSE, templates, CI). Usar `references/baseline-audit-checklist.md` mas adicionar checks OSS: `for f in LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md .github/FUNDING.yml; do test -e "$f" && echo "EXISTS" || echo "MISSING"; done`
3. **SPEC.md estrutura dupla:** Seção de Requisitos Funcionais vem do SDD (features); seção de Requisitos Não-Funcionais vem do PE (performance, segurança, testing); seção de Governância OSS vem do OSS Excellence (licença, templates, contribuição).
4. **PLAN.md organiza em duas trilhas paralelas:**
   - **Trilha A (PE/OSS):** Infraestrutura e governância — CI/CD setup, LICENSE, templates, SECURITY.md, testing pipeline, code review automation. Tasks de F0 (fundação).
   - **Trilha B (SDD):** Features — cada feature passa por SPECIFY → PLAN → IMPLEMENT → VERIFY. Tasks de F1+ (features).
   - Trilha A pode rodar em paralelo com Trilha B, mas Trilha A deve estar completa antes do primeiro release público.
5. **AGENTS.md inclui** convenções de código (PE), processo de contribuição (OSS), e workflow de spec (SDD).
6. **CONTEXT.md inclui** state do CI/CD, state dos artefatos OSS, e baseline do código.

**Entrega para o user:** Apresentar a integração como um plano unificado, não como três documentos separados. O valor está em mostrar COMO os frameworks se conectam, não em repetir cada um isoladamente.

**Pitfall (learned 2026-08-02):** `.planning/` DEVE ser adicionado ao `.gitignore` em repos públicos. Os arquivos SDD (SPEC.md, PLAN.md, AGENTS.md, ROADMAP.md) contêm estimativas de esforço, decisões bloqueadas, gaps de auditoria OSS, e roadmap interno — não devem ser expostos publicamente. Adicionar `.planning/` ao `.gitignore` antes de qualquer commit, e verificar com `git status .planning/` (deve retornar vazio). Se o repo já tem um commit de segurança pendente (sem push), incorporar o `.gitignore` update via `git commit --amend --no-edit`.

**Padrão de Decisões Bloqueadas:** Quando o planejamento identifica que certas tasks dependem de decisões humanas externas (ex: "qual provider de newsletter?", "qual plataforma de donate?"), criar uma tabela **BD-XX** numerada no ROADMAP.md com: ID, decisão, impacto (quais tasks bloqueia), e quem decide. Cada task no PLAN.md referencia seu BD-XX na coluna "Bloqueado Por". Isso previne que o agente tente implementar tasks que dependem de decisões não tomadas.

## Override/Blocking Spec Pattern

When stakeholder feedback fundamentally changes the architectural approach after specs are already written, create an **override spec** that supersedes the affected specs.

**Real case (LouvorJA, 2026-07-07):** 6 specs were written for dynamic DB-backed endpoints (F1-T3, F2-T1 through F2-T4). After implementation as PR #28, the upstream maintainer (Mayco) commented: "The desktop/web app should NOT communicate with the API. It should only read locally downloaded JSON files." This invalidated the entire architectural approach of the existing specs.

**Pattern:**
1. Create a new spec with a new phase ID (e.g., F6-T1) that documents the architectural change
2. In the spec's RFs, explicitly declare which existing specs/RF-IDs are superseded
3. Update `.planning/specs/README.md` to mark the blocked specs and add a dependency note
4. Mark the new spec as "Draft — Pending stakeholder decision" if there are options (e.g., Option A: remove routes vs Option B: refactor routes to serve static)
5. Do NOT delete the old specs — they may be partially reusable (same JSON shape, same OpenAPI annotations) under the new architecture

**Pitfall:** Don't re-implement the old specs without confirming the architectural direction. The override spec should be approved FIRST.

## SaaS-from-Scratch Planning Pattern (commercial app "reverse" / clone)

When user asks to "reversa"/clone a commercial app (e.g., Play Store SaaS) and build their own version as a real product:

1. **Requirements source: the store listing itself.** Extract features from the Play Store description AND the changelog ("O que há de novo" reveals feature history — "texto mensagem múltipla", "cartão fidelidade" appeared there). Requirements-level reversal needs no APK decompilation. Also mine: target audience list, pricing/trial model, developer info (solo dev = market proof).
2. **Baseline = the user's own repos, not the competitor's code.** Search the filesystem for prior projects in the same domain and produce a reuse table (feature × repo × status). For o PO, scheduling/booking domain: `<clone local>/ignitecall-app` (scheduling domain: UserTimeInterval/Scheduling, NextAuth+Prisma), `<clone local>/hairday` (vanilla agenda UX), `~/Piano-Louvor-JA-flutter` + `<clone local do projeto>/api` (Flutter offline-first + Hono/Drizzle bootstrap patterns). Port CONCEPTS to the target stack, never code.
3. **Deliverable set for a new commercial product (write yourself, Mega-Spec rule #5):** SPEC.md (RFs grouped by business pillar with EARS criteria + RNFs mensuráveis + Fora de Escopo + BD table) + ARCHITECTURE.md (schema, endpoints, jobs, offline-first strategy, ADRs) + DESIGN.md (tokens, linted) + AGENTS.md (with blocked-decisions BD-XX table so agents STOP) + PLAN.md (phased, each phase shippable, hour estimates) + CONTEXT.md (sources, reuse map, gotchas).
4. **Phase the PLAN by business pillar** (e.g., Fundação → Agenda → Engajamento → Financeiro → Comercialização). Store-billing/paywall tasks always depend on human-only decisions (Play Console account, brand name, WhatsApp Cloud API/Meta Business) — block them as BD-XX rows so the agent never fakes them.
5. **Engineering invariants for money/scheduling SaaS:** money = integer cents (`price_cents`); scheduling overlap = Postgres exclusion constraint (tstzrange + EXCLUDE gist), never client-side; availability/slots computed in backend only (multi-channel: app + public link must share one source of truth); WhatsApp = wa.me deep links first (zero cost/approval), Cloud API later behind a BD decision.

Real case (2026-09): `~/projetos/minha-agenda-pro` — SaaS agenda para beleza (clone de com.minhaagenda), 15 RFs, 4 fases ~98h, paleta vinho/blush/dourado (identidade do segmento, validada no lint do design.md CLI).

## Pitfalls

1. **Spec vaga = código errado.** "Make it fast" não é spec. "P95 < 200ms under 100 RPS" é.
2. **Pular SPECIFY pra ir direto pro código.** É a tentação #1. Sempre resista.
3. **Reviewer usando o mesmo modelo que implementou.** Viés de confirmação. Sempre use modelo diferente.
4. **Spec sem "Fora de Escopo".** Sem isso, scope creep é garantido.
5. **Spec sem critérios mensuráveis.** "Deve ser bonito" → como verificar? Use EARS ou Given/When/Then.
6. **Não versionar a spec.** SPEC.md vai no git. É um contrato.
7. **Implementer lendo a spec inteira.** Não. O Planner já quebrou em tasks. Implementer só vê sua task.
8. **Baseline audit em repo com branches inacessíveis localmente.** Se `git branch` não mostra o branch de referência (ex: `electron`), use `gh api` para acessar arquivos individualmente. **Pitfall:** `gh api .../contents/<dir>?ref=branch` retorna um **array** para diretórios (não objeto) — `.content | base64 -d` falha. Use `git/trees/<branch>?recursive=1` para listings e `contents/<file>?ref=<branch>` apenas para arquivos individuais.
9. **Pular RED phase (TDD) mesmo com pressa.**
10. **Subagent 413 silencioso em Mega-Spec.** Quando dispatch paralelo de 3+ subagentes para escrever SPEC+PLAN+AGENTS+CONTEXT, o payload total (baseline audit + instrucoes + dados de contexto) pode exceder o limite do delegate_task. Subagentes retornam status=completed em <1s mas nao escrevem nada — os arquivos ficam inalterados. **Fix:** Verificar `wc -l` dos 4 arquivos apos dispatch. Se inalterados, escrever voce mesmo. **Prevencao:** Para Mega-Spec, escrever os 4 arquivos diretamente com write_file — mais rapido e mais confiavel. "Bora rushar" NÃO justifica implementar antes de testar. O fluxo correto é SPECIFY → RED (teste falha) → GREEN (código) → REFACTORAR. Implementar sem testes cria divida TDD que baixa coverage. Se o usuário pediu pra acelerar, delegue RED+GREEN no mesmo subagent -- mas NUNCA pule o RED. Coverage é pilar do Project Excellence e não pode baixar. Quando perceber que implementou sem testes, pare imediatamente e escreva os testes ANTES de qualquer nova task.
11. **Nome ambíguo de skill ao carregar PE.** `skill_view(name='project-excellence')` falha com erro "Ambiguous skill name" quando a skill existe em mais de uma localização no filesystem (ex: duplicada em `software-development/project-excellence/` e uma cópia flat). **Fix:** Sempre carregar via path completo: `skill_view(name='software-development/project-excellence')`. Como SDD diz que "PE é carregado implicitamente", o agent tenta o nome bare e falha. **Prevenção:** Ao carregar qualquer skill que se sabe estar duplicada, usar o path categorizado desde o início.
12. **electron-builder respeita .gitignore (causa raiz de "app não abre").** Arquivos que estão no `.gitignore` do repo NÃO entram no app.asar, mesmo se foram adicionados com `git add -f`. O git rastreia, mas o builder ignora. Se o Electron tenta ler um arquivo em runtime (EULA, configs, templates) que está numa pasta ignorada, `readFileSync` falha com ENOENT dentro do asar → `UnhandledPromiseRejection` → processo travado → janela nunca abre. **Fix:** Qualquer arquivo lido em runtime Electron DEVE estar numa pasta coberta pelo `build.files` no package.json e NÃO no `.gitignore`. Verificar ambos antes de empacotar. **Caso real (Piano-Louvor-JA/app, 08/08/2026):** EULA em `docs/LEGAL/eula/` (`docs/` no .gitignore) → ENOENT em produção, app travava no Windows.
13. **SDD aplicado a docs/infra também gera artefatos de tracking reais.** Quando o usuário pede planejamento SDD + PE + OSS para um repo de documentação/hub (ex: wiki de onboarding), o PLAN deve incluir tasks de tracker (Project v2, milestones) como entregáveis de F1 — não só arquivos markdown. Receita testada: `references/github-project-v2-graphql-recipe.md`. Caso real (Piano-Louvor-JA/docs, 15/09/2026): F1 = estrutura + README + AGENTS.md + Project v2 com campos Área/Prioridade/Fase + 4 milestones × 5 repos, tudo verificado via API antes de push.
14. **Org branch flow é inegociável — inclusive em repos de docs.** Push direto na main "por pragmatismo" (repo quase vazio) foi corrigido pelo usuário: o fluxo feat → PR staging → PR main vale para TODOS os repos, incluindo docs/wiki/infra. Nunca decidir unilateralmente que um repo é "low-risk enough" para pular o PR flow; se em dúvida, perguntar uma vez, default = fluxo da org. Setup do fluxo vem ANTES do primeiro commit de conteúdo (fetch origin staging para a ref existir; ver oss-project-excellence P36 para recovery de commit na branch errada e o "No commits between" quando staging==main).

## Cross-Repo Feature Linking Pattern

When two repos need to share configuration data (keyboard shortcuts, design tokens, API schemas):

1. **One repo owns the data** — creates and maintains a JSON file (e.g., `docs/keyboard-shortcuts.json`)
2. **Other repo consumes via GitHub raw URL** — `$fetch('https://raw.githubusercontent.com/org/repo/main/docs/file.json')`
3. **Issues in BOTH repos** — owner issue: "maintain JSON"; consumer issue: "consume dynamically with fallback"
4. **Document the contract** in AGENTS.md of both repos: file path, URL, schema, fallback strategy
5. **Fallback** — consumer always has a hardcoded fallback if the raw URL fails or rate limits

**Real case (Piano-Louvor-JA, 06/08/2026):**
- piano-app #54: `docs/keyboard-shortcuts.json` (14 atalhos, 3 idiomas, keyCodes, globalShortcuts)
- piano-site #9: `useKeyboardShortcuts()` composable fetches raw URL, cache 1h, fallback hardcoded

**Rule:** NUNCA hardcodar no consumidor. O JSON é a fonte única de verdade. Se não está no JSON, não existe.

## Multi-Repo Parity Analysis Pattern

When a project needs feature parity with 2+ reference repos (forks, originals, competitors):

1. **Baseline audit each repo** — use `gh api .../git/trees/branch?recursive=1` to list structure without cloning
2. **Gap matrix** — Feature × Has/Doesn't × Priority × Source table
3. **One SPEC per source repo** — not one mega-spec. Each source has different architecture/strengths
4. **Create issues** — one per gap, with `label=priority` and body referencing the source repo code
5. **Single consolidated PLAN** — phases ordered by priority + dependencies across all sources
6. **AGENTS.md** — stack, patterns, "WHAT NOT TO DO", cross-repo linking rules

**Key insight:** When 2+ forks exist, features often COMPLEMENT each other. Fork A may have SSE + power blocker, fork B may have SQLite + crypto. Create separate issues per feature with explicit `Referência:` pointing to the fork that has working code.

**Real case (Piano-Louvor-JA/app, 06/08/2026):**
- louvorja/desktop (Delphi original) → 7 parity issues
- juanaleixo/louvorja (advanced fork) → 12 new feature issues
- elvieira/LouvorJA (infra-robust fork) → 8 infrastructure issues
- Total: 43 issues, 3 SPEC files, 2 PLAN files, ~98h mapped

## References

- `references/spec-template.md` — template completo de SPEC.md
- `references/context-template.md` — template de CONTEXT.md (4º entregável do Planning-Only mode)
- `references/baseline-audit-checklist.md` — técnica de baseline audit batched via execute_code (roda 10-15 comandos em paralelo, resultados estruturados)
- `references/cross-platform-port-example.md` — exemplo real de Cross-Platform Port Spec (Electron→Flutter): feature matrix, entity mapping TS→Dart, design system port, blocked decisions
- `references/minha-agenda-pro-planning-2026-09.md` — exemplo real de SaaS-from-Scratch (clone de app comercial): SPEC/ARCHITECTURE/DESIGN/AGENTS/PLAN/CONTEXT completos em ~/projetos/minha-agenda-pro/.planning/
- `references/github-project-v2-graphql-recipe.md` — receita testada de GitHub Project v2 + milestones via gh CLI (quando o plano vira tracker real): pitfalls de createProjectV2Field (color+description obrigatórios, "Repo" é nome reservado, fragment `{... on ProjectV2SingleSelectField{id}}` dentro de projectV2Field), criação em conta USER (não org — `gh api orgs/<name>` 404 mas `users/<name>.type == "User"`), e como distinguir Pages-404 por plano free vs falta de admin (checar `repos/<repo>.permissions.admin`)
- `references/github-projects-docs-hub-setup.md` — setup completo de docs hub SDD (proven 2026-09-15 Piano-Louvor-JA/docs): mesma receita de Projects v2 + padrão mkdocs para repo onde docs vivem na raiz (sync script raiz→docs-src, README.md↔index.md por diretório, normalização de links por profundidade, NUNCA commitar index.md gerado na raiz) + Pages em repo private (exige plano pago → ship workflow inativo e gate como BD-XX) + baseline audit de getting-started lendo package.json/pubspec reais via gh api
- `references/agenda-iasd-jau-backend-fases.md` — exemplo real de spec multi-fase
- `references/web-parity-modules-analysis-2026-07-06.md` — Module gap analysis, electron→web port patterns, projection architecture
- GitHub Spec Kit: https://github.com/github/spec-kit
- Addy Osmani "How to write a good spec": https://addyosmani.com/blog/good-spec
- Martin Fowler SDD: https://martinfowler.com/articles/exploring-gen-ai/sdd-tools.html
- Red Hat SDD: https://developers.redhat.com/articles/2025/10/22/how-spec-driven-development-improves-ai-coding-quality

## Skills Relacionadas

- `writing-plans` — Fase PLAN detalhada
- `subagent-driven-development` — Fase IMPLEMENT com 2-stage review
- `requesting-code-review` — Fase VERIFY
- `test-driven-development` — TDD dentro de cada task
- `project-excellence` — Quality gates e CI
- `systematic-debugging` — Quando VERIFY encontra bugs
- `design-md` — Design tokens para a spec. **Nota de sessão (2026-09):** o CLI `@google/design.md` rejeita frontmatter YAML cru (usa bloco ```yaml fenced, sem `---` interno) e o export DTCG funciona mesmo com warnings. Ao projetar pra um CLIENTE com site, extraia a marca real (sweep de getComputedStyle + webfonts reais via performance entries) em vez de inventar paleta de referências genéricas. Recipe completo: `references/design-md-authoring-notes.md`
