# Regression Guard

> **Metodologia pública** — Consumers analysis, 4-layer gate, pre-edit checks. Aplica-se a qualquer stack.

---
> Problema que resolve: soluções novas quebram constantemente o que já estava pronto. Causa raiz: mudança implementada sem mapear consumidores e sem prova de não-regressão.

## A regra central

> Mudança sem matriz de impacto + teste de regressão + evidência executada NÃO está pronta.

## Pipeline mínimo (ordem fixa)

1. **P0 — Matriz de impacto (antes de escrever código)**
   - Grep de consumidores: quem importa/chama o que vai mudar (código, rotas, schemas, stores).
   - Plataformas afetadas (web/app/APK/desktop) quando o projeto é multi-plataforma.
   - Saída: tabela `mudança → risco → regressão exigida` (3 colunas, no PR/commit msg).
   - Sem matriz = não começa.
2. **Teste de regressão PRIMEIRO (TDD)**
   - Teste que exercita o comportamento ATUAL que não pode quebrar → deve passar antes da mudança.
   - Teste do comportamento NOVO → deve falhar (RED) → implementa (GREEN).
   - Bug descoberto no caminho vira teste de regressão antes do fix.
3. **Builder isolado** — implementa só a peça; refactoring "aproveitando" é commit separado ou não existe.
4. **Gates executáveis (evidência real, nunca "de olho")**
   - typecheck + lint (comando EXATO da CI, escopo igual ao da CI)
   - suíte de testes dos módulos tocados E dos consumidores mapeados no P0
   - smoke do fluxo afetado ponta-a-ponta (UI: rota registrada + elemento no template + ação persiste estado — "componente renderiza" não conta)
   - build
5. **Crítico cego** — perfil/modelo diferente do implementador; recebe SÓ spec/barra/diff/evidência; veredito binário PASSOU/FALHOU. Na stack do o PO: implementer GLM → crítico perfil `gauntlet` (nemotron) ou `reviewer`.
6. **Loop Shumer (sem cap)** — itera até TODOS os Bn passarem com evidência; só escala se o critério exigir decisão que muda o desenho da barra.

## Critérios que viram barra (Bn) sempre que aplicáveis
- B1: comportamento atual X tem teste verde antes e depois da mudança
- B2: cada consumidor da matriz P0 tem regressão rodada com evidência (output real)
- B3: paridade web/app/APK quando fluxo é multi-plataforma (evidência em cada uma)
- B4: smoke ponta-a-ponta do fluxo afetado, não só unit test
- B5: CI verde no comando exato da CI (reproduzido localmente primeiro)
- B6: Stryker mutation score 100% nos módulos tocados (mutante vivo = teste que não valida)

## Regras de ouro (fonte: pesquisa 27/09 — AI Engineer/Shrabony, DORA 2025, PSP/Humphrey)
1. **Gate que só loga warning não é gate — é sugestão.** Todo Bn falho BLOQUEIA o avanço da peça; nunca "seguir com ressalva". (DORA 2025: AI acelera throughput mas aumenta instabilidade — quem compensa é o gate bloqueante, não a ferramenta.)
2. **Contrato na fronteira**: quando a mudança altera schema/payload/formato de saída que outro módulo consome, existe um teste de contrato explicitando o formato esperado (Zod schema testado, snapshot de payload). Uma skill que muda o formato quebra 3 downstream — o contrato pega na fronteira, não 3 módulos depois.
3. **Ledger PSP (Humphrey) automatizado**: toda quebra que escapa pro prod entra no ledger do Obsidian (data, o que quebrou, causa raiz, qual Bn teria pego). O ledger alimenta os Bn da PRÓXIMA mudança naquele módulo — defeito previsível vira checklist (padrão PSP: erros são previsíveis, checklist personalizado é o que pega).
4. **Revisão em varreduras focadas**: crítico cego varre o diff N vezes, uma por tipo de defeito (regressão de consumidor, contrato quebrado, estado persistido, edge case de input) — varredura única mista pega menos (evidência PSP: reviews estruturados acham até 80% dos defeitos antes do teste).

## Anti-padrões adicionais
- "CI verde" citado sem reproduzir o comando da CI localmente = gate fantasma.
- Warning-only check deixando a peça avançar = gate de mentira (virou sugestão).
- Claim específico ("reduziu X%") sem rastreabilidade de fonte no report = report bloqueado.

## Integração
- Este guard é a camada de REGRESSÃO dentro do gauntlet-loop (carregar `ai-agents:gauntlet-loop` para features grandes; este guard sozinho basta para mudanças médias).
- **Jev (System One, free)** pluga 2 gates baratos: P3 pré-gate do crítico cego (`python3 ~/.hermes/scripts/jev_ask.py --preset diff_gate "<diff>" "<matriz>"` — noul ≥0.5 = revisão completa, <0.5 = lite) e P5 gate de incerteza (`--preset confidence` — noul 0.35-0.65 = escala pro humano, não chuta). Free tier oscila (422 transitório) — helper tem retry; se falhar 2x, seguir com revisão normal e NÃO bloquear por indisponibilidade do Jev. Detalhes: Obsidian `01-Inbox/Jev - integração no fluxo.md`.
- qa-agent Gate 1 (spec compliance) usa a matriz P0 como spec mínima quando não há SPEC.md formal.
- Lições de quebra real (postmortem curto: o que quebrou, por quê, qual critério Bn teria pego) vão pra nota do projeto no Obsidian e viram Bn na próxima mudança daquele módulo.

## Anti-padrões
- "Passou nos testes unitários" sem rodar os consumidores → não é regressão verificada.
- Mudar schema/contrato sem grep de quem consome → quebra garantida em outro módulo.
- Corrigir bug encontrado de marcha, sem teste → vai voltar.
- Crítico do mesmo modelo/perfil que implementou → viés de confirmação.
