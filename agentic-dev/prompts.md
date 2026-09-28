# Prompts e padrões agênticos

> O que funciona (e o que não funciona) ao desenvolver Piano LouvorJA com
> agentes de IA. Destilado de sessões reais de desenvolvimento.

## Padrões que funcionam

### 1. Contexto antes de código

O erro mais caro é o agente começar sem entender o domínio. Sempre:

1. Carregar a skill de domínio relevante (ver [skills.md](skills.md))
2. Ler o AGENTS.md do repo alvo
3. Ler a task/spec antes do código

### 2. Baseline audit antes de SPEC

Nunca especificar algo que já existe. Verificar com ferramentas reais:

```bash
# o que existe no repo (sem clonar)
gh api repos/pianolouvorja/<repo>/git/trees/main?recursive=1 --jq '.tree[].path'
# scripts reais disponíveis
gh api repos/pianolouvorja/<repo>/contents/package.json --jq '.content' | base64 -d
```

Docs mentem mais que código: checkmarks `[x]` em PLANs antigos não são prova.

### 3. Paridade por contrato

Ao portar feature de desktop para web/apk, o contrato é a **API**, não o código:

- Replicar os mesmos endpoints (`/v1/custom`, `/file/custom/*`, `/json_db/*`)
- Cada plataforma usa seu idioma (Vue/Flutter) — nunca transpilar componentes
- Testar os 3 clientes contra a mesma API

### 4. Spec antes de feature grande (SDD)

Estrutura de 4 arquivos em `.planning/<feature>/`: SPEC.md → PLAN.md →
AGENTS.md → CONTEXT.md. Templates em [templates/](templates/spec-template.md).

### 5. Verificação com evidência real

"Nunca digite done sem prova":

- Testes rodando de verdade (colar output, não resumir)
- Build passando
- Para UI: screenshot ou inspeção de DOM

## Anti-padrões (que já causaram retrabalho)

| Anti-padrão | Consequência | Correção |
|-------------|--------------|----------|
| Assumir que migration rodou no deploy | Coluna faltando em produção | Sempre verificar pós-deploy (ver workflows/releases.md) |
| Arquivo runtime no .gitignore do Electron | ENOENT no asar, app não abre | Arquivo runtime fora do .gitignore e dentro do build.files |
| `window.confirm` | UI inconsistente / bloqueios | Sempre `AppConfirm` |
| Teste que reimplementa a função em vez de importá-la | Falso positivo (mantenedor quebra a função real e o teste passa) | Importar e invocar o código real |
| Abrir app Electron no browser | Testando a coisa errada | Janela Electron = o app |
| Assumir decisão humana (credenciais, contas de store) | Retrabalho / bloqueio | Parar e perguntar (BD-XX na spec) |
| Push direto na main | Fluxo quebrado, review pulada | feat → PR staging → PR main |

## Modelos por tipo de task

| Task | Modelo |
|------|--------|
| Spec / plan | O mais capaz disponível |
| Implementação simples, task isolada | Rápido |
| Implementação complexa, multi-arquivo | Capaz |
| Review | Diferente do que implementou (evita viés) |
| Debug de root cause | Capaz + ferramentas (logs, adb, CDP) |
