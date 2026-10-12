# LouvorJA .ja Liturgy

> **Metodologia pública** — spec do formato .ja (liturgia). Aplica-se a qualquer stack.

---
Arquivo INI exportado pelo LouvorJA Delphi (Windows-1252). Parser TS: `src/modules/liturgy/services/liturgy-ja-import.ts` (desktop+web). Parser Dart: `lib/core/services/liturgy/ja_liturgy_parser.dart` (APK). Spec viva no Obsidian: `00-Projects/PIANO/Importar-Liturgia-JA-Delphi.md`.

## Regras do formato (validadas com arquivo real da igreja + fonte Delphi)

1. **Encoding**: UTF-8 fatal → fallback cp1252 (Delphi exporta ANSI).
2. **Seções**: `[item_<timestamp>]` com campos `tipo/item/subitem/cor/musica/dir/dir_info/checked/escolha`; seção `[Geral]` com chaves `1..7` = listas de ids separadas por `;`.
3. **DIAS: 1=domingo .. 7=sábado** (NOMES_DIAS em fmCopiaLiturgiaDia.pas). Mapa errado `1=segunda` desloca TODA a semana (domingo parava no sábado). Chave 7 = Escola Sabatina (sábado manhã); chave 6 = culto sexta noite.
4. **checked = DATA dd/mm/aaaa** (não boolean!): item done apenas se `checked == hoje` (fmMenu.pas compara com FormatDateTime('dd/mm/yyyy', Now)). Virada do dia = reset automático. Importar .ja antigo chega com checks limpos.
5. **Chaves `alteraordem-N`** em [Geral] são timestamps de reordenação — ignorar (só aceitar 1..7 numéricos).
6. **tipos**: `musica` (campo musica=id da API louvorja — IDs batem direto, ex 2000="Mãos"), `anotacao`, `arquivo` (tipo por extensão do `dir`). Cuidado: `subtipo` tem valores ja/div/hasd — NÃO confundir com `tipo`.
7. **Dedup de ids**: referências duplicadas entre dias usam sufixo `_d<dia>_i<n>` — normalizar com `_baseId` (regex `_d\d+_i\d+$`).
8. **Cores Delphi**: `$00BBGGRR` (BGR invertido) → hex ARGB.

## Pitfalls críticos (bugs reais já cometidos)

- **Race condition no import via bloc/event queue**: empilhar `DayChanged/ClearDay/AddItem` sem aguardar cada um corrompia dias (ClearDay executava depois dos Adds e apagava o importado). CORRETO: montar lista final por dia em memória e gravar DIRETO no repository (`saveItems`), depois recarregar o dia.
- **Import duplicado**: pré-checar duplicados (tipo+nome+musicaId+filePath) ANTES de alterar nada; oferecer "Sobrescrever dias" (repo zera e regrava) vs "Manter e adicionar novos". Sem pré-checagem o mesmo .ja reimportado duplica itens.
- **FilePicker Android**: SAF rejeita `FileType.custom` com extensão `.ja` (mime desconhecido) → usar `FileType.any` + validar extensão no código.
- **Dado deslocado residual**: após corrigir bug de mapeamento, dados já salvos permanecem errados — usuário deve reimportar com "Sobrescrever" (o código não re-mapeia storage antigo).

## Fonte de verdade Delphi
github.com/louvorja/desktop (Pascal): fmMenu.pas (checked data), fmCopiaLiturgiaDia.pas (NOMES_DIAS), dmComponentes.pas (persistência).

## Referências
- `references/ja-format-spec.md` — spec completa do formato, amostra real, mapeamentos TS/Dart, cores, API de música, arquivos irmãos (itensAgendados.xml etc.).
