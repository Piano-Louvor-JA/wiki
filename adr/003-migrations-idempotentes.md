# ADR-003: Runner de migrations statement-a-statement idempotente

**Status:** Aceita · **Data:** 2026 · **Decisor:** o PO · **Origem:** PR api#88

## Contexto

O runner de migrations executava o arquivo SQL inteiro de uma vez. Dois bugs
em produção decorreram disso:

1. A migration 020 continha um `;` dentro de comentário, quebrando o split.
2. O deploy deixou a migration 022 parcialmente aplicada (faltou a coluna
   `custom_musics.owner_id`), corrigida na mão com `ALTER TABLE`.

O problema central: migrations **parciais** silenciosas deixam o schema num
estado que nenhum script de migration consegue mais consertar sozinho.

## Decisão

O runner (`pianolouvorja/api`):

- Executa **statement a statement** (split respeitando `;` dentro de
  comentários).
- Tolerância a erros **idempotentes** por statement (ex.: `column already exists`,
  `table already exists`) e segue adiante — um statement que já rodou não
  aborta a migration.
- Erros reais (syntax, constraint) continuam abortando.

## Consequências

- ✅ Deploy nunca mais deixa migration "pela metade sem saber" — cada
  statement ou aplica ou já estava aplicado.
- ✅ Re-executar a migration é seguro (idempotência por statement).
- ⚠️ Pós-deploy segue **obrigatório** verificar que tudo rodou (ver
  workflows/releases.md) — o runner tolera idempotência, não substitui
  verificação.
- ⚠️ Escrever migrations assumindo que statements podem re-executar.
