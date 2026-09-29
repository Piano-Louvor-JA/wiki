# QA Agent — 7 Gates

> **Metodologia pública** — Gatekeeper: spec compliance, mutation, lighthouse, LGPD, rastreabilidade RF-ID. Aplica-se a qualquer stack.

---
> "Eu não aprovo código. Eu aprovo **evidência de que o código funciona.**"

## O Que É

O agente QA é o **Reviewer/Verifier** no fluxo SDD. Ele recebe SPEC.md + código implementado e retorna um veredito estruturado. **Nunca aprova o próprio trabalho** — sempre é um subagent com contexto fresco e modelo diferente do implementer.

**Diferença de `requesting-code-review`:** aquele roda pre-commit (security, lint, regressão). Este roda **pós-implementação** (spec compliance, mutation testing, Lighthouse, LGPD, quality real dos testes). São complementares, não substitutos.

## Quando Invocar

- **Fase VERIFY do SDD** — após IMPLEMENTAR, antes de RELEASE
- **PR review** — quando alguém abre PR no seu repo
- **Sprint review** — antes de marcar milestone como done
- **Quando o o PO diz "revisa isso"** — carrega esta skill

## Modos de Execução

Antes de rodar, **classificar o PR** pra determinar modo:

```
DIFF_SIZE = git diff main...HEAD --stat | tail -1
RF_COUNT  = grep -cE "^### RF-[0-9]+" SPEC.md
HAS_UI    = grep -rl "tsx\|jsx\|html\|vue\|svelte" src/ --include="*.tsx" --include="*.jsx" 2>/dev/null
HAS_PII   = grep -rniE "(cpf|cnpj|email|telefone|endereco|nome.*completo|rg|data.*nascimento)" src/ 2>/dev/null
```

| Modo | Quando | Gates | AI Reviewer |
|------|--------|-------|-------------|
| **FULL** | Feature nova, refactor, >100 LOC ou >3 RFs | Todos os 7 | OBRIGATÓRIO modelo diferente |
| **LITE** | Bug fix trivial, <100 LOC, ≤2 RFs | 1, 2, 4, 7 | OBRIGATÓRIO modelo diferente |
| **YOLO** | Rush mode (1-3 linhas, typo, hotfix prod) | 1, 7 | OBRIGATÓRIO modelo diferente |

> Gates 3 (Mutation), 5 (Lighthouse), 6 (LGPD) são **condicionais** — só rodam em FULL mode E se o projeto tem o requisito. Gate 7 nunca pula.

## Rastreabilidade: RF-ID obrigatório (Ponto #3)

**Toda SPEC.md DEVE ter RFs numerados.** Sem RF-ID, QA não consegue rastrear.

Formato padronizado que aparece em TODOS os artefatos:

```
SPEC.md:      ### RF-001: Login deve aceitar email + senha
Código:       // RF-001: login handler
Teste:        describe('RF-001: login', () => { ... })
Commit:       feat(auth): RF-001 login handler
QA Report:    RF-001: ✅ src/auth/login.ts:42 + auth.test.ts:15 (3 cenários)
```

Se a spec não tem RFs numerados, **Gate 1 FAIL automático** com mensagem:
`SPEC.md não tem RFs numerados. Reescrever spec com formato RF-XXX antes do QA.`

## Pipeline de 7 Gates

```
SPEC.md + CODE + RF-ID
      │
      ▼
┌── GATE 1: SPEC COMPLIANCE ──────────────────────────┐
│ Cada RF-XXX da spec → existe no código? Tem teste?  │
│ FAIL se qualquer RF não atendido                     │
│ NEW: Se QA acha edge case não previsto na spec →     │
│   SPEC FEEDBACK: volta pra ESPECIFICAR, não fix     │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 2: COVERAGE REAL ───────────────────────────┐
│ Coverage >= 90% + branch >= 80% em lógica complexa │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 3: MUTATION TESTING (CONDICIONAL) ──────────┐
│ FULL mode apenas. Stryker score 100% (perfeito)    │
│ LITE/YOLO: SKIP                                    │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 3.5: CONTRACT + VISUAL (CONDICIONAL) ────────┐
│ FULL mode apenas.                                    │
│ Contract: schema/payload que outro módulo consome    │
│   tem teste de contrato (Zod/snapshot) atualizado?   │
│ Visual (HAS_UI): toHaveScreenshot vs baseline —      │
│   diff inesperado BLOQUEIA; baseline novo só via     │
│   review (nunca auto-update no merge).               │
└──────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 4: SECURITY SCAN ───────────────────────────┐
│ OWASP + secrets + dependency audit                  │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 5: LIGHTHOUSE (CONDICIONAL) ────────────────┐
│ Só se HAS_UI=true AND FULL mode                     │
│ SEO >= 95, A11y >= 95, Perf >= 85 mobile            │
│ LITE/YOLO ou backend-only: SKIP                     │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 6: LGPD (CONDICIONAL) ──────────────────────┐
│ Só se HAS_PII=true AND FULL mode                    │
│ Consentimento, esquecimento, logs, criptografia     │
│ Sem PII ou LITE/YOLO: SKIP                          │
└─────────────────────────────────────────────────────┘
      │ PASS
      ▼
┌── GATE 7: INDEPENDENT REVIEWER (AI) ───────────────┐
│ MODELO DIFERENTE do implementer (ver tabela abaixo) │
│ Procura: logic errors, edge cases, code smell       │
│ NUNCA PULA — nem em YOLO mode                       │
└─────────────────────────────────────────────────────┘
      │ ALL PASS
      ▼
   ✅ APPROVE → RELEASE
      │
      ▼
┌── POST-RELEASE MONITORING (Ponto #6) ──────────────┐
│ Se bug em prod → gh issue create → volta pra MAPEAR │
│ Ciclo fecha: MAPEAR → SPEC → IMPL → QA → RELEASE    │
│   → MONITOR → (bug?) → MAPEAR [loop]                │
└─────────────────────────────────────────────────────┘
```

**Qualquer gate FAIL = veredito REQUEST_CHANGES ou BLOCK. Sem meio-termo.**

## Spec Feedback Loop (Ponto #2)

Se o QA Agent encontra um **edge case que a spec não previu**, NÃO fazer fix de código direto. Fluxo correto:

```
QA acha edge case não previsto
        │
        ▼
SPEC FEEDBACK → volta pra ESPECIFICAR
        │
        ├── É bug da spec? → Adicionar RF-XXX novo na spec
        ├── É comportamento correto não documentado? → Documentar na spec
        └── É genuinely novo requisito? → Nova TASK na spec
        │
        ▼
Spec atualizada → Re-aprovar com PO (o PO)
        │
        ▼
SÓ ENTÃO voltar pra IMPLEMENTAR com a spec corrigida
```

**Por quê:** Se QA faz fix de código sem atualizar spec, a spec fica desatualizada. Espec é a fonte da verdade — código segue spec, não o contrário. Spec desatualizada = waterfall automatizado (código diverge da spec silenciosamente).

## Como Executar (Passo a Passo)

### Pré-requisitos

```bash
# Classificar PR (determinar modo)
DIFF_LINES=$(git diff main...HEAD --stat | tail -1)
RF_COUNT=$(grep -cE "^### RF-[0-9]+" SPEC.md 2>/dev/null || echo 0)
HAS_UI=$(grep -rl "\.tsx\|\.jsx\|\.vue\|\.svelte\|\.html" src/ 2>/dev/null | head -1)
HAS_PII=$(grep -rniE "(cpf|cnpj|email|telefone|endereco|nome.*completo|rg|data.*nascimento)" src/ --include="*.ts" --include="*.js" --include="*.tsx" 2>/dev/null | head -1)

echo "MODE: $([ "$DIFF_LINES" -lt 100 ] && [ "$RF_COUNT" -le 2 ] && echo LITE || echo FULL)"

# Coletar contexto
SPEC_PATH=".planning/<feature>/specs/" ou "SPEC.md" ou ".hermes/specs/"
git diff main...HEAD --name-only  # arquivos modificados
git diff main...HEAD              # diff completo (se < 15k chars, senão split)
```

### Gate 1: Spec Compliance (OBRIGATÓRIO — todos os modos)

Para cada RF-XXX na SPEC.md:

```bash
# 1. Identificar RFs na spec
grep -E "^### RF-[0-9]+" SPEC.md

# 2. Para cada RF, buscar implementação (usar RF-ID)
grep -rn "RF-001\|<keyword_from_rf>" src/

# 3. Para cada RF, buscar teste (usar RF-ID)
grep -rn "RF-001\|<keyword_from_rf>" *.test.* *.spec.*
```

**Checklist por RF:**
- [ ] Código implementa o comportamento descrito
- [ ] Teste cobre o happy path
- [ ] Teste cobre edge case / input inválido
- [ ] Critério de aceite (EARS/BDD) é verificável mecanicamente
- [ ] **Rastreabilidade:** RF-XXX aparece no código, no teste, e no commit

**SPEC FEEDBACK CHECK:** QA encontra comportamento que spec não descreve?
- Sim, é bug da spec → SPEC FEEDBACK (ver fluxo acima)
- Sim, é bug do código → REQUEST_CHANGES
- Não → continuar

**Saída:**
```
RF-001: ✅ Implementado em src/auth/login.ts:42 (RF-001 marcado) + teste auth.test.ts:15 (3 cenários)
RF-002: ❌ Implementado mas SEM teste de edge case (input vazio). Teste existe mas não cobre.
RF-003: ❌ NÃO implementado — spec pede rate limiting, código não tem
RF-004: ⚠️ SPEC FEEDBACK — edge case encontrado (timeout do provider de auth) não previsto na spec
```

### Gate 2: Coverage Real

```bash
# Node/TypeScript
npx vitest run --coverage 2>&1 | tail -30

# Python
python -m pytest --cov=src --cov-report=term-missing 2>&1 | tail -30

# Go
go test -coverprofile=coverage.out ./... && go tool cover -func=coverage.out | tail -30
```

**Análise:**
- Coverage total >= 90%? (threshold do project-excellence)
- Branch coverage em arquivos com lógica complexa (conditionals, loops) >= 80%?
- Linhas não cobertas são triviais (type guards, error boundaries) ou críticas (business logic)?

### Gate 3: Mutation Testing (CONDICIONAL — FULL mode apenas)

```bash
# Stryker (JS/TS) — ver skill stryker-mutation-testing
npx stryker run 2>&1 | tail -20

# Mutmut (Python)
mutmut run 2>&1 | tail -20
```

**Threshold:**
- Mutation score 100%: OK (padrão do projeto — só para na perfeição)
- < 100%: WARNING (mutante vivo = teste que não valida)

**Se Stryker não estiver configurado**: pular este gate com WARNING e recomendar configuração.

### Gate 4: Security Scan (OBRIGATÓRIO — todos os modos)

```bash
# Secrets hardcoded
git diff main...HEAD | grep "^+" | grep -iE "(api_key|secret|password|token)\s*=\s*['\"][^'\"]{6,}['\"]"

# Dependency audit
npm audit --audit-level=high 2>&1 | tail -10    # Node
pip-audit 2>&1 | tail -10                         # Python
cargo audit 2>&1 | tail -10                       # Rust

# Shell injection / SQL injection / eval
git diff main...HEAD | grep "^+" | grep -E "os\.system\(|subprocess.*shell=True|execute\(f\"|\.format\(.*SELECT"
```

### Gate 5: Lighthouse (CONDICIONAL — FULL mode + HAS_UI apenas)

**Pular se:** `HAS_UI=false` OU modo LITE/YOLO

```bash
# Via CLI (se instalado)
npx lighthouse http://localhost:3000 --only-categories=seo,accessibility,performance,best-practices --output=json --output-path=/tmp/lh.json --chrome-flags="--headless" 2>&1 | tail -5

# Parse scores
cat /tmp/lh.json | jq '.categories | to_entries[] | {category: .key, score: .value.score}'
```

**Thresholds (padrão do projeto):**
- SEO >= 95 ✅ / < 95 ❌
- A11y >= 95 ✅ / < 95 ❌
- Perf >= 85 (mobile) ✅ / < 85 ❌
- Best Practices >= 90 ✅ / < 90 ❌

### Gate 6: LGPD (CONDICIONAL — FULL mode + HAS_PII apenas)

**Pular se:** `HAS_PII=false` OU modo LITE/YOLO

Verificar:
```bash
# Buscar coleta de dados pessoais
grep -rniE "(cpf|cnpj|email|telefone|endereco|nome.*completo|rg|data.*nascimento)" src/ --include="*.ts" --include="*.js" --include="*.py"
```

Se encontrar dados pessoais:
- [ ] Base legal documentada (consentimento, contrato, obrigação legal)
- [ ] Política de privacidade acessível
- [ ] Direito ao esquecimento implementado (endpoint de deleção)
- [ ] Logs não expõem dados pessoais em texto plano
- [ ] Dados sensíveis criptografados em trânsito (TLS) e em repouso

### Gate 7: Independent AI Reviewer (OBRIGATÓRIO — NUNCA pula)

**MODELO DIFERENTE DO IMPLEMENTER.** Sempre. Em TODOS os modos.

**Mapeamento concreto de modelos (Ponto #4):**

| Implementer usou | Reviewer DEVE usar | Por quê |
|------------------|-------------------|---------|
| Claude (Anthropic) | GPT-4/Gemini | Arquitetura e training data diferentes |
| GPT-4 (OpenAI) | Claude/Kimi K2 | Diferente vendor = diferente bias |
| GLM (Z.AI) | Claude/Nemotron | Stack da o PO: implementer GLM → reviewer Nemotron |
| Kimi K2 (Groq) | GLM/Claude | Implementer Kimi → reviewer GLM/Claude |
| Nemotron | GLM/Kimi | Implementer Nemotron → reviewer GLM |
| Desconhecido | Sempre Claude ou GPT-4 | Default pra fresh eyes |

**Na stack do o PO (free tier):**
- Implementer = GLM-5.1 (Z.AI) → Reviewer = **Nemotron** ou **Kimi K2** (Groq)
- Usar `delegate_task` com `model` override explícito

```python
delegate_task(
    goal="""You are a SENIOR code reviewer. Fresh eyes, no context bias.
You have NEVER seen this code before. Be skeptical. Be thorough.

Review the following code changes against the spec.

SPEC:

DIFF:
---
[INSERT GIT DIFF]
---

STATIC ANALYSIS RESULTS:
[INSERT findings from gates 1-6]

Return ONLY this JSON:
{
  "verdict": "APPROVE" | "REQUEST_CHANGES" | "BLOCK",
  "spec_compliance": [
    {"rf": "RF-001", "status": "PASS|FAIL", "evidence": "file:line", "test": "file:line"}
  ],
  "logic_errors": [
    {"severity": "critical|high|medium|low", "file": "...", "line": N, "issue": "...", "fix": "..."}
  ],
  "security_concerns": [
    {"severity": "...", "issue": "...", "fix": "..."}
  ],
  "quality_issues": [
    {"type": "missing_test|dead_code|code_smell|perf|a11y", "file": "...", "issue": "..."}
  ],
  "spec_feedback": [
    {"rf": "RF-XXX", "issue": "edge case not covered in spec", "suggestion": "..."}
  ],
  "summary": "2-3 sentence overall assessment"
}

RULES:
- verdict BLOCK = security critical OR spec RF not implemented OR logic error in critical path
- verdict REQUEST_CHANGES = any gate failed but fixable
- verdict APPROVE = all gates passed, no critical issues
- Be SPECIFIC: cite file:line, not vague descriptions
- Don't be nice. Be RIGHT.""",
    context="Independent QA review. Return only JSON.",
    toolsets=["terminal", "file"],
    # CRITICAL: modelo diferente do implementer
    # Se implementer usou GLM, reviewer usa Nemotron ou Kimi
)
```

## Veredito Final

```
╔════════════════════════════════════════════════════════╗
║                    QA REPORT v2                         ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  MODO: [FULL / LITE / YOLO]                            ║
║  VEREDITO: [APPROVE / REQUEST_CHANGES / BLOCK]         ║
║  FIX CYCLE: [0/3]                                      ║
║                                                        ║
║  Gate 1 (Spec Compliance):  ✅/❌ [X/Y RFs atendidas]   ║
║  Gate 2 (Coverage):         ✅/❌ [XX% total, XX% branch]║
║  Gate 3 (Mutation):         ✅/❌/⏭️ [XX% ou SKIP]      ║
║  Gate 4 (Security):         ✅/❌ [N issues]             ║
║  Gate 5 (Lighthouse):       ✅/❌/⏭️ [SEO/A11y/Perf/BP]  ║
║  Gate 6 (LGPD):             ✅/❌/⏭️ [N/A or N issues]   ║
║  Gate 7 (AI Reviewer):      ✅/❌ [verdict]              ║
║  Gate 7 Modelo: [Nemotron / Kimi / Claude — ≠ impl]    ║
║                                                        ║
║  SPEC FEEDBACK: [lista de RFs que precisam spec update]║
║  Issues Críticos: [lista ou "nenhum"]                   ║
║  Sugestões: [lista ou "nenhuma"]                        ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
```

## Fluxo pós-veredito

| Veredito | Ação | Quem decide | Notificação |
|----------|------|-------------|-------------|
| **APPROVE** | Prosseguir para RELEASE | Automático | — |
| **REQUEST_CHANGES** | Auto-fix loop (ver abaixo) | Fix subagent | — |
| **BLOCK** | Escalar pro PO AGORA | Humano | Discord DM + issue |
| **SPEC FEEDBACK** | Volta pra ESPECIFICAR | o PO aprova spec | Discord DM |

## Auto-fix Loop (Ponto #1 — critério de parada explícito)

Se REQUEST_CHANGES e issues são claros:

```python
MAX_FIX_CYCLES = 3

for cycle in range(MAX_FIX_CYCLES):
    # Spawn fix agent (contexto diferente do implementer E do reviewer)
    delegate_task(
        goal=f"""Fix ONLY these issues. Do NOT refactor, rename, or add features.

Cycle {cycle + 1}/{MAX_FIX_CYCLES}.

Issues:
[INSERT logic_errors + security_concerns FROM QA REPORT]

After fixing, describe what you changed.""",
        context="Fix only reported issues.",
        toolsets=["terminal", "file"]
    )

    # Re-run QA after fix
    qa_result = run_qa_gates(spec, diff)

    if qa_result.verdict == "APPROVE":
        break
    elif qa_result.verdict == "BLOCK":
        escalate_to_rafael(qa_result)
        break

# CRITICAL: se chegou aqui sem APPROVE, BLOCK automático
if qa_result.verdict != "APPROVE":
    escalate_to_rafael(
        reason=f"Auto-fix loop exhausted after {MAX_FIX_CYCLES} cycles. "
               f"Last verdict: {qa_result.verdict}. "
               f"Issues: {qa_result.critical_issues}"
    )
```

**Regra absoluta:** 3 ciclos sem APPROVE = **BLOCK automático**, mesmo se não for security. Escala pro PO com todos os contextos.

**Anti-spin:** Se QA reporta o MESMO issue 2 ciclos seguididos (fix não resolveu), pula direto pra BLOCK no ciclo 3.

## Escalonamento pro PO (Ponto #8 — SLA)

Quando BLOCK ou fix loop exausto:

```bash
# 1. Criar issue no repo
gh issue create \
  --title "🚨 QA BLOCK: [resumo do problema]" \
  --body "QA Agent bloqueou após [N] ciclos de fix.

Issues não resolvidas:
[listas com file:line]

Último veredito: [REQUEST_CHANGES/BLOCK]
Modo: [FULL/LITE/YOLO]
Diff: [link pro PR ou commit]"

# 2. Notificar via Discord (canal de trabalho)
# Mensagem direta pro PO no Discord
```

**SLA:** BLOCK não fica silencioso. Sempre cria issue + notifica no Discord. O o PO decide: resolver manualmente, ajustar spec, ou dar override.

## Post-RELEASE Monitoring (Ponto #6 — fecha o ciclo)

```
RELEASE
   │
   ▼
MONITOR (24-48h pós-deploy)
   ├── Error rate subiu? → gh issue create → volta pra MAPEAR
   ├── User reporta bug? → gh issue create → volta pra MAPEAR
   ├── Lighthouse caiu em prod? → gh issue create → volta pra MAPEAR
   └── Tudo OK após 48h? → ✅ Fechar ciclo
```

**Self-healing loop completo:**
```
MAPEAR → OBSIDIAN → ESPECIFICAR → IMPLEMENTAR → VERIFY → RELEASE → MONITOR
   ▲                                                        │
   └──────────── bug em prod? ←─────────────────────────────┘
```

Sem esse arco, RELEASE é fim de linha. Com ele, o sistema se auto-corrigi.

## Seleção de Modelo por Gate

| Gate | Modelo Ideal | Por quê |
|------|-------------|---------|
| 1 (Spec) | Modelo capaz | Precisa raciocinar sobre semântica |
| 2 (Coverage) | — (tooling) | Vitest/pytest faz o trabalho |
| 3 (Mutation) | — (tooling) | Stryker/mutmut faz o trabalho |
| 4 (Security) | Modelo capable | Precisa entender padrões de ataque |
| 5 (Lighthouse) | — (tooling) | Lighthouse CLI faz o trabalho |
| 6 (LGPD) | Modelo capable | Precisa raciocinar sobre base legal |
| 7 (AI Review) | **MODELO DIFERENTE DO IMPLEMENTER** | Evita viés |

## Como Invocar via delegate_task

```python
# QA Agent completo no fluxo SDD
qa_result = delegate_task(
    goal="""Load skill 'qa-agent' and run QA pipeline.

SPEC: [caminho para SPEC.md]
Changed files: [lista]
Diff: [git diff main...HEAD]

Classify mode (FULL/LITE/YOLO) based on diff size and RF count.
Run appropriate gates.
Return QA Report with verdict.""",
    toolsets=["terminal", "file", "web"],
    context="Full QA review. Be thorough. Be skeptical.",
    # Gate 7 reviewer: modelo DIFERENTE do implementer
    # Se implementer usou GLM, override pra Nemotron/Kimi aqui
)
```

## Rodando QA de diffs GRANDES (lição de campo 11/09/2026, PR de 263 commits / 34k linhas)

Um único subagent FULL em diff de 30k+ linhas **estoura o timeout de 600s** do delegate_task (2 timeouts seguidos, zero relatório). O que funcionou:

- **Fatia os gates em 2+ subagents menores em paralelo**: (a) Gate 1+2 spec/coverage, (b) Gate 4+7 security/review — cada um com escopo fechado de arquivos e instrução "seja específico, file:line". MESMO ASSIM podem estourar: dois dispatches fatiados de ~600s também deram timeout (API calls lentas do reviewer, não tamanho do diff). Quando o 2º round também falha, **para de re-despachar** e consolida manualmente.
- **`flutter test --coverage` trava em suites grandes** (CPU→0 em deadlock, sem lcov após 15+ min — bug conhecido do collector com ~800 testes). Kill e não insistir. Proxy aceitável: % de arquivos de `lib/` cujo basename aparece em algum `test/**/*_test.dart` + confirmar que cada arquivo da leva é exercitado por ≥1 teste.
- **Greps objetivos valem mais que subagent**: Gate 1 (feature → impl em lib/ + teste em test/ via grep de pares nome-arquivo) e Gate 4 (secrets no diff via `git diff | grep "^+" | grep -iE "(secret|password|token)..."`, token fora de prefs via `grep setString | grep -i token`) rodam em segundos no terminal. O valor real do subagent é o Gate 7 fresh-eyes, não os greps.
- **`dart analyze` como evidência barata de Gate 7**: `use_build_context_synchronously` acha async gaps reais; `dart analyze --fatal-warnings --no-fatal-infos` replica exatamente o gate da CI do APK (infos não falham, warnings sim — 3 unused imports em test files derrubaram a CI).
- **CI vermelha ≠ código quebrado**: Flutter CI com `--fatal-warnings` derruba por unused import em arquivo de TESTE que o dev não roda localmente (`dart analyze` cobre test/ também — sempre rodar sobre o repo todo antes de push). Mesma lição na API: `npx biome ci src/ test/` é o comando da CI, não `npx biome check src/` — escopo divergente faz o local passar e a CI falhar.
- **CI falha legada numa PR velha**: nem sempre é regressão tua — a PR #68 da API falhava lint DESDE A CRIAÇÃO (`let result;` → noImplicitAnyLet) e ninguém tinha visto. Reproduzir o comando exato da CI localmente antes de culpar o diff novo.
- **Gate 7 timeout também acontece em diffs PEQUENOS**: subagent Nemotron estourou 600s com poucas API calls (lentidão do provider, não tamanho). 1 timeout = consolidar com review manual (leitura dos pontos quentes do diff + greps da lógica crítica) e marcar "⚠ consolidado manualmente" no report — o report continua válido. Nunca re-despachar indefinidamente.

## Rodando QA de diffs GRANDES (lição de campo 11/09/2026, PR de 263 commits / 34k linhas)

Um único subagent FULL em diff de 30k+ linhas **estoura o timeout de 600s** do delegate_task (2 timeouts seguidos, zero relatório). O que funcionou:

- **Fatia os gates em 2+ subagents menores em paralelo**: (a) Gate 1+2 spec/coverage, (b) Gate 4+7 security/review — cada um com escopo fechado de arquivos e instrução "seja específico, file:line". MESMO ASSIM podem estourar: dois dispatches fatiados de ~600s também deram timeout (API calls lentas do reviewer, não tamanho do diff). Quando o 2º round também falha, **para de re-despachar** e consolida manualmente.
- **`flutter test --coverage` trava em suites grandes** (CPU→0 em deadlock, sem lcov após 15+ min — bug conhecido do collector com ~800 testes). Kill e não insistir. Proxy aceitável: % de arquivos de `lib/` cujo basename aparece em algum `test/**/*_test.dart` + confirmar que cada arquivo da leva é exercitado por ≥1 teste.
- **Greps objetivos valem mais que subagent**: Gate 1 (feature → impl em lib/ + teste em test/ via grep de pares nome-arquivo) e Gate 4 (secrets no diff via `git diff | grep "^+" | grep -iE "(secret|password|token)..."`, token fora de prefs via `grep setString | grep -i token`) rodam em segundos no terminal. O valor real do subagent é o Gate 7 fresh-eyes, não os greps.
- **`dart analyze` como evidência barata de Gate 7**: `use_build_context_synchronously` acha async gaps reais; `dart analyze --fatal-warnings --no-fatal-infos` replica exatamente o gate da CI do APK (infos não falham, warnings sim — 3 unused imports em test files derrubaram a CI).
- **CI vermelha ≠ código quebrado**: Flutter CI com `--fatal-warnings` derruba por unused import em arquivo de TESTE que o dev não roda localmente (`dart analyze` cobre test/ também — sempre rodar sobre o repo todo antes de push). Mesma lição na API: `npx biome ci src/ test/` é o comando da CI, não `npx biome check src/` — escopo divergente faz o local passar e a CI falhar.
- **CI falha legada numa PR velha**: nem sempre é regressão tua — a PR #68 da API falhava lint DESDE A CRIAÇÃO (`let result;` → noImplicitAnyLet) e ninguém tinha visto. Reproduzir o comando exato da CI localmente antes de culpar o diff novo.
- **Gate 7 timeout também acontece em diffs PEQUENOS**: subagent Nemotron estourou 600s com poucas API calls (lentidão do provider, não tamanho). 1 timeout = consolidar com review manual (leitura dos pontos quentes do diff + greps da lógica crítica) e marcar "⚠ consolidado manualmente" no report — o report continua válido. Nunca re-despachar indefinidamente.

## Pitfalls

0. **Subagent QA em diff grande estoura o timeout de 600s.** Review de 30k+ linhas via `delegate_task` não cabe na janela — um subagent FULL e dois fatiados (Gate 1+2 / Gate 4+7) morreram todos com "status=timeout" e zero relatório. Padrão que funciona: **rodar os gates diretamente com evidência local** (grep de pares impl/teste, `dart analyze`, `flutter test`, diff de segurança) e reservar subagents para diffs pequenos (<2k linhas) ou review pontual de arquivo único. Consolidar o QA REPORT no formato do skill mesmo assim — o report vale, marcando "⚠ consolidado manualmente".
0b. **`flutter test --coverage` trava em suites grandes** (Flutter): CPU vai a ~0% e o lcov nunca é escrito — deadlock do collector com ~800 testes (15+ min sem output). Não esperar o timeout; matar o processo e usar proxy de cobertura: % de arquivos de `lib/` cujo basename aparece em algum `test/**/*_test.dart` + confirmar que cada arquivo crítico da leva é exercitado por ≥1 teste. Anotar como dívida de tooling, não de teste.
0c. **CI vermelha ≠ código quebrado, e o comando local tem que ser IGUAL ao da CI.** Três casos reais na mesma sessão: (1) Flutter CI com `--fatal-warnings --no-fatal-infos` derruba por unused import em arquivo de TESTE — rodar `dart analyze` sobre o repo TODO (inclui test/) antes de push; (2) API: o comando da CI é `npx biome ci src/ test/`, não `check src/` — escopo divergente faz o local passar e a CI falhar; (3) PR velha com lint falhando DESDE A CRIAÇÃO (`let result;` → noImplicitAnyLet) não é regressão nova — reproduzir o comando exato do workflow localmente antes de culpar o diff.

1. **Aprovar porque "parece funcionar".** QA não chuta. Cada RF precisa de evidência.
2. **Usar o mesmo modelo que implementou.** Viés de confirmação. SEMPRE modelo diferente no Gate 7.
3. **Pular Mutation Testing em FULL mode.** Coverage 100% com testes que não testam nada = falso positivo.
4. **Lighthouse em projeto sem UI.** Desperdício. Gate condicional resolve.
5. **LGPD ignorado "porque é só um MVP".** Multa é de 2% do faturamento até R$50M.
6. **Auto-fix loop infinito.** Máximo 3 ciclos. Depois, BLOCK + escala.
7. **Diff muito grande (>15k chars).** Split por arquivo. Review cada um separadamente.
8. **Security scan só grep.** Combinar com `npm audit` / `pip-audit` pra dependency vulnerabilities.
9. **Reportar issues sem file:line.** "Tem um bug no auth" é inútil. "src/auth.ts:42 — null check missing" é útil.
10. **Ser bonzinho.** QA não é seu amigo. QA é seu seguro. Se dúvida = REQUEST_CHANGES.
11. **Fix sem spec feedback.** Se QA acha edge case novo, spec precisa ser atualizada PRIMEIRO (Ponto #2).
12. **BLOCK silencioso.** Sempre cria issue + notifica Discord. Nunca deixar o PO sem saber.
13. **Gate 7 pulado em YOLO.** Gate 7 NUNCA pula. Mesmo em rush mode, fresh eyes é obrigatório.
14. **RF sem rastreabilidade.** RF-001 precisa estar no código, no teste, e no commit. Sem isso, evidência fica solta.
15. **Comando de CI divergente do comando local.** Reproduzir localmente o comando EXATO do workflow (`npx biome ci src/ test/` vs `check src/`, `flutter analyze --fatal-warnings --no-fatal-infos` sobre o repo todo incluindo test/) antes de pushar — escopo ou flags diferentes fazem o local passar e a CI falhar (aconteceu 2x na mesma sessão).
16. **Commitar untracked de other-features no push de emergência.** `git add -A` num repo com `.planning/`, symlinks de dados e worktrees de outras features incorpora lixo no commit (aconteceu: SPEC.md de bíblia + symlink `media` entraram num push de lint fix). Antes de `git add`, revisar `git status --short` e addar arquivos EXPLÍCITOS. Se o lixo já subiu: force-push do estado limpo imediatamente (commit só teu, sem co-autores no remote ainda).
17. **Lint de "hardcoded credential" que casa concatenação de variável.** Regex `(token|secret|...)\s*[:=]` no CI barra `?token='+encodeURIComponent(token)` (query string de WebSocket) — falso positivo que travou uma PR por dias. Regex correta exige valor LITERAL: `(token|secret|...)\s*[:=]\s*['\"][^'\"]{4,}['\"]`, e mesmo assim validar localmente contra o arquivo real (concatenação tipo `'token=' + var` ainda casa por causa da aspas de fechamento — filtrar `\+encodeURIComponent`). Se o lint é teu (workflow próprio), consertar o padrão; nunca renomear a variável de código pra agradar grep.
18. **E2E "pula se API offline" com `late String token` crasha na CI em vez de pular.** No runner onde a API local é inalcançável, o setUpAll sai pelo catch e o guard `if (token.isEmpty)` acessa o late não-inicializado → `LateInitializationError` → teste falha em vez de skip. Correto: `String? token;` + local promotion (`final tok = token; if (tok == null || tok.isEmpty) return;`) e TODO uso posterior usa o local — o analyzer não promove field de classe dentro de closure async, por isso o local é obrigatório (inclusive no `tearDownAll`). Isso derrubou a CI do APK com 3 "failures" que localmente nunca apareciam (a API estava no ar no dev).
19. **E2E contra API viva pega bug de AMBIENTE que mock nunca vê.** No mesmo dia, o E2E real falhou porque a migration de ownership (`022`) nunca tinha sido aplicada no DB de dev (`custom_musics` sem `owner_id` → INSERT quebrado com "Erro ao criar música" genérico). Os 874 testes mockados passavam todos. Quando E2E falha só num ambiente: desconfiar de migração/esquema ANTES de desconfiar do código — comparar `PRAGMA table_info` / esquema com o que o código espera, e aplicar a migration do repo (`src/db/migrations/*.sql`) no ambiente faltante.
20. **Lint de credencial hardcoded que casa concatenação de variável.** Regex `(token|secret|...)\s*[:=]` num workflow próprio barra `?token='+encodeURIComponent(token)` (query string de WebSocket) — falso positivo que travou a PR #11 do palco-receiver por dias. Regex correta exige valor LITERAL entre aspas: `(token|...)\s*[:=]\s*['\"][^'\"]{4,}['\"]` — e validar localmente contra o arquivo real, porque `'token=' + var` ainda casa via aspas de fechamento (filtrar `\+encodeURIComponent` no pipeline do grep). Consertar o padrão do lint; nunca renomear variável de código pra agradar grep.
21. **`--full-page` no playwright screenshot para browser tooling antigo**: se o binário não estiver instalado, `npx playwright install chromium` resolve; o screenshot full-page é a evidência visual certa pra bugs de duplicação de UI (botão duplicado por cadeia v-if quebrada não aparece em contagem de hrefs).

## Integração com SDD

```
SPECIFY → PLAN → IMPLEMENT → [AQUI: QA AGENT] → RELEASE → MONITOR
                                    │                           │
                            ┌───────┴───────┐                   │
                            │  7 Gates      │           bug? ───┘
                            │  Spec Check   │──→ SPEC FEEDBACK ──→ ESPECIFICAR
                            │  Coverage     │
                            │  Mutation     │
                            │  Security     │
                            │  Lighthouse   │
                            │  LGPD         │
                            │  AI Reviewer  │
                            └───────────────┘
```

**No project-excellence:** QA Agent roda na transição IMPLEMENTAR → RELEASE.
**No subagent-driven-development:** QA Agent é o Stage 2 do two-stage review (Stage 1 = requesting-code-review).
**Spec Feedback:** se QA encontra gap na spec, volta pra ESPECIFICAR antes de fix de código.
