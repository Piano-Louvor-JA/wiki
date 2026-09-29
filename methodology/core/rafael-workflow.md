# Rafael Workflow

> **Metodologia pública** — ciclo SDD → Kanban Hermes → Gauntlet → Release. Aplica-se a qualquer stack.

---
Skill índice: NÃO duplica conteúdo das skills irmãs — carrega a certa na fase certa e aplica os padrões de eficiência transversais. Funciona com QUALQUER LLM (os padrões moram aqui, não no modelo).

## Pipeline de fases (decidir qual fase e despachar)

| Fase | Quando | Skill executora | Artefato |
|------|--------|-----------------|----------|
| 0. MAPEAR | task nova ou premissa duvidosa | `software-development/spike` + baseline audit | tabela spec×código + **matriz de impacto** (consumidores/rotas/plataformas) |
| 1. OBSIDIAN | antes de congelar qualquer plano | `note-taking/obsidian` | SPEC/PLAN/BARRA no vault |
| 2. ESPECIFICAR | feature nova | `software-development/spec-driven-development` | SPEC.md com RF-IDs |
| 3. PLAN | spec aprovada | `software-development/writing-plans` | PLAN.md com tasks F-T |
| 4. IMPLEMENTAR | execução | `software-development/test-driven-development` + `software-development/regression-guard` (sempre que toca código existente) + `gauntlet-loop` (se barra verificável) | commits por peça |
| 5. VERIFY | peça/feature pronta | `software-development/qa-agent` (7 gates) + `software-development/requesting-code-review` + gate de regressão (suíte dos consumidores da matriz P0) | tabela RF→Bn→evidência |
| 6. RELEASE | funcionalidade INTEIRA pronta | `github/github-pr-workflow` | 1 PR única base staging |
| 7. MONITOR | pós-merge 24-48h | `software-development/systematic-debugging` | issue → nova peça |

**Roteamento rápido:** task de 1 tacada com critério binário → pula pra fase 4 com barra mínima. Feature inteira → pipeline completo. Bug em produção → fase 7 direto + peça própria se autorizado.

## Regras transversais (valem em TODAS as fases)

### Do Rafael (inegociáveis)
1. Obsidian = source of truth; planeja ANTES de implementar.
2. Evidência = execução real com output; nunca "de olho".
3. Commit+push ao fim de TODO ciclo, na branch certa (`git status -sb` antes).
4. feat → staging → main; PRs SEMPRE base staging; NUNCA push direto em staging/main; main só via PR de staging.
5. 1 PR única quando a funcionalidade INTEIRA estiver pronta (não uma por fase).
6. Reformatting pré-existente NUNCA em commit de feature.
7. NUNCA `git checkout -- .` sem revisar status antes.
8. Review do Ezequias antes de merge.
9. TODO visível na UI = bug.
10. Testes com vídeo: música SACRA IASD (Athus, Vox, Arautos), nunca mundana.
11. NUNCA `git commit`/`push --no-verify` (Rafael 24/09: hooks husky rodam SEMPRE; se lint-staged reescrever arquivo → `git add` + re-commit; nunca contornar gate).
12. **Regression Guard (inegociável, 27/09)**: mudança em código existente sem matriz de impacto + teste de regressão + evidência executada NÃO está pronta. Carregar `software-development/regression-guard` na fase 4. Ledger de quebras: Obsidian `01-Inbox/Regression Guard - prevenção de quebras.md`.

### Anti-parada do Gauntlet (herdadas — valem até fora de loops)
1. **Contrato de turno**: turno só termina com (a) peça fechada com evidência, (b) bloqueio externo real (`kanban_block`), ou (c) próxima ação DESPACHADA. Proibido encerrar com "vou rodar X" / "próximo passo: Y".
2. **3 strikes**: ferramenta falhou 2-3x → troca de ESTRATÉGIA (outra abordagem/outro caminho), nunca retry idêntico.
3. **Rate limit ≠ parar**: retry 1x, depois o agente executa localmente com evidência real e loga a degradação. Janela de rate limit é de horas — nunca esperar.
4. **Operação >60s em background** (`terminal(background=true, notify=true)`); turno segue noutra peça; heartbeat no kanban em tasks >1h.
5. **Fila nunca vazia**: enquanto uma peça tá em gate, a próxima já foi despachada.
6. **Retomada pós-interrupção**: ler o arquivo de estado (GAUNTLET-STATE.md ou equivalente), validar git status, continuar do ponto exato. Nunca re-planejar do zero, nunca perguntar "onde paramos".
7. **Autonomia concedida = loop fechado**: "não pare até X" = parada só no X com evidência. Decisões de detalhe: assumir a recomendada, marcar "assumida (confirmar)", seguir. Só bloquear se a decisão mudar o desenho da barra/spec.

### Eficiência de LLM (padrões frontier, Fable 5.1 leak — doc completo no Obsidian: 03-Permanent/Patterns/system-prompts-frontier-padroes-hermes.md)
1. Falha/skip vem na PRIMEIRA frase do report, mesmo quando o resto deu certo.
2. Mensagem final autossuficiente: lead com o outcome; sem "quer que eu...?" decorativo; números em bloco próprio.
3. Antes de bloquear por pergunta, esgota tudo que NÃO depende da resposta.
4. Batch de tool calls independentes numa única resposta; deferred tools carregados em UM search amplo.
5. Ambiguidade rotineira: julga como colega cuidadoso; pergunta só quando leituras diferentes = trabalho materialmente diferente.
6. Escopo é o deliverable: não estreitar/alargar/transformar o pedido silenciosamente.
7. Se usuário reafirma após pushback: é decisão dele, executa full sem relitigar.
8. Anti-clichê: cortar "basicamente", "na verdade" — honestidade é default.
9. Memória: só fato [stated] pelo Rafael; escolha dele entra, recomendação minha não-adotada não entra.

### Contexto por projeto (decisões já tomadas — não re-perguntar)
- **Jev (System One, $0)**: gate barato de decisão binária. P1 `--preset command_guard` antes de comando com efeito colateral (noul ≥0.7 = não executa, escala); P2 `--preset task_triage` na fase 0 roteia a task; P4 `--preset severity` prioriza o ledger de quebras. Helper: `~/.hermes/scripts/jev_ask.py`. Free tier tem janelas de 422 transitório — 2 falhas seguidas = seguir sem o gate, não bloquear. Detalhes: Obsidian `01-Inbox/Jev - integração no fluxo.md`.
- **PIANO (Piano-Louvor-JA)**: carregar skill de domínio do repo tocado (app/web/api/apk). Org: feat→staging→main. Prod API: ssh usuario@servidor (502 = Caddy restart transitório).
- **AGENVA (minha-agenda)**: AGENTS.md do repo é lei. Firebase key pública; google-services.json versionado (fix PR apk#20). Device teste: A15 do Rafael via adb Wi-Fi.
- **OSS externo**: seguir `github/oss-project-excellence` — checar PRs competidoras ANTES de despachar; checklist pré-push completo; conventions do repo mandam.

## Modo autônomo (como invocar)

O usuário ativa com meta + "não pare até X":

```
rafael-workflow: <meta> — não pare até <critério com evidência>
```

Ao ativar:
1. Criar GAUNTLET-STATE.md (template: `ai-agents/gauntlet-loop` → references/gauntlet-state-template.md) ANTES do primeiro build.
2. Congelar BARRA B1..Bn em commit próprio (derivada de SPEC + código real, nunca só da spec — P0 baseline audit).
3. Loop: selecionar alvo → builder → crítico cego (veredito binário PASSOU/FALHOU/ESCALAR) → próxima peça já despachada.
4. Interrupção ÚNICA permitida: mesmo Bn falhando 3 ciclos → kanban_block(needs_input) com evidência.
5. Parada final: X com evidência + PR aberta base staging + gates verdes.

Prompts prontos: `ai-agents/gauntlet-loop` → references/gauntlet-master-prompt.md (padrão coverage/mutation) e gauntlet-piramide-prompts.md (builder/crítico por peça).

## Pitfalls de orquestração (os que matam o fluxo inteiro)

| Pitfall | Prevenção |
|---------|-----------|
| Re-planejar a cada turno | GAUNTLET-STATE.md é a memória; 1ª ação = ler estado |
| Skill bare-name ambígua (ex.: `project-excellence` existe em 2 categorias) | carregar com path completo (`software-development/project-excellence`) |
| Gate fantasma (CI verde que nunca rodou de verdade) | validar gate localmente com a ferramenta real antes de citar como evidência |
| Formatter --write come patches pendentes | re-ler arquivo após formatter; grep marcadores da mudança ao fechar peça |
| Coverage 100% "de olho" | JSON→python por linha (receita: gauntlet-loop → coverage-100-recipe.md) |
| Decisão de detalhe bloqueando o loop | agrupar perguntas em 1 call com opção recomendada; timeout = assumir recomendada + marcar p/ confirmar |
| PR fragmentada por fase | confirmar granularidade de PR no início e registrar no PLAN |
| Divergência spec×código descoberta tarde | baseline audit ANTES de congelar barra (caso Coletâneas 16/09: spec pedia JWT, código já usava token opaco) |

## Referências
- Pipeline mestre: `software-development/project-excellence` v9.7 (MAPEAR→OBSIDIAN→ESPECIFICAR→IMPLEMENTAR→VERIFY→RELEASE→MONITOR)
- Loop: `ai-agents/gauntlet-loop` v1.3 (barra congelada, crítico cego, anti-parada)
- Eficiência: Obsidian `03-Permanent/Patterns/system-prompts-frontier-padroes-hermes.md`
- Kanban como superfície: peça = task, DAG via parents, crítico = reviewer, 3 ciclos = request_changes
