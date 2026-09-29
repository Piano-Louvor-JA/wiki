# LouvorJA Delphi Interop

> **Metodologia pública** — formatos de dados do Delphi original. Aplica-se a qualquer stack.

---
## Fonte de verdade
O código Delphi é a referência SEMPRE que um formato der dúvida:
- `github.com/louvorja/desktop` (Pascal) — `fmCopiaLiturgiaDia.pas`, `fmMenu.pas`, `dmComponentes.pas/.dfm`, `fmItensAgendados.pas`
- Arquivos reais do Rafael: `/media/contribuidor/NovoVolume/nvme-mint/Downloads/liturgia.ja`, `itensAgendadosCategorias.xml`

## liturgia.ja (INI, cp1252 ou UTF-8)
- Seções `[item_<timestamp>]` com `tipo` (musica/anotacao/arquivo), `item`, `subitem`, `musica` (ID = id_music da API), `cor` ($BBGGRR Delphi), `checked`, `dir`.
- `[Geral]`: chaves **1=DOMINGO..7=SÁBADO** (confirmado `NOMES_DIAS` em fmCopiaLiturgiaDia.pas; chave 7 = Escola Sabatina sábado manhã). NÃO é 1=segunda!
- `alteraordem-N` são timestamps de reordenação — ignorar (só aceitar 1–7 numéricos).
- Sufixo `_d<dia>_i<n>` no id = mesma entrada referenciada em outro dia; dedupe por id base.
- **`checked` é DATA dd/mm/aaaa, não boolean**: item `done` só se == HOJE (reset automático na virada do dia — fmMenu.pas compara com `FormatDateTime('dd/mm/yyyy', Now)`). Importar .ja antigo = tudo limpo.

## DATAPACKET XML (itens agendados)
```xml
<DATAPACKET Version="2.0"><METADATA>...</METADATA><ROWDATA><ROW ID=".." NOME=".."/></ROWDATA></DATAPACKET>
```
- `itensAgendadosCategorias.xml`: ROW {ID, NOME}
- `itensAgendados.xml`: ROW {ID, CATEGORIA(fk), DATA, NOME, ARQUIVO, ARQUIVO_INFO}
- **ARQUIVO_INFO é flag de caminho** (`'I'` = relativo ao dir do exe), NÃO observação de equipe. Delphi não tem campo de observações — `notes` é extensão NOSSA.
- Parsers prontos: `datapacket_parser.dart` (APK) e `datapacket-parser.ts` (app/web) — testados com arquivo real.

## configPT.ja
Config de máquina (monitores, layout, versão exe) — só [Musicas] cores/tamanhos de projeção valem como preset de tema. Decisão: não integrar o resto.

## .slja (apresentações de música)
Port Dart completo em 11/09/2026: `Piano-Louvor-JA-flutter/src/lib/core/services/slja.dart`
+ import UI no APK (`import_slja.dart`, FAB "Adicionar → Importar .slja" na coletânea própria).
Formato detalhado, pitfalls do port e regras de tempo (tempo_hms = segundos,
tempo = bytes BASS): ver `references/delphi-slja-format.md`.

### .slja.zip (wrapper do WhatsApp) — regra do Rafael (11/09): aceitar AMBOS, não um ou outro
WhatsApp/mensageiros anexam sufixo `.zip` na extensão: `musica.slja` vira
`musica.slja.zip` — um ZIP EXTERNO contendo o .slja interno (zip dentro de
zip). O import TEM que aceitar `.slja` puro E `.slja.zip`:
- File picker: `XTypeGroup(extensions: ['slja', 'zip'])`.
- `parseSlja` (Dart): se o payload é zip, procurar dentro o primeiro `*.slja`
  e parseá-lo; `.slja` direto continua funcionando; nem-zip-nem-slja →
  `FormatException` clara. 4 testes em `slja_test.dart` cobrindo os casos.
- **Pendente no web** (piano-app): `MediaEditorView.vue` importa
  `shared/services/slja` que NÃO existe na branch `feat/custom-auth-clean`
  (o arquivo existe no commit `f3880d5` de outra branch) — portar o mesmo fix
  de wrapper zip quando a branch for resolvida (`accept=".slja"` linha ~821).

## PITFALLS comprovados em sessão
1. **Import APK: gravar DIRETO no repository** — empilhar `DayChanged/ClearDay/AddItem` na fila do bloc causa race (dia limpo depois de importado, estado parcial). Montar lista final em memória → `saveItems()` → recarregar dia.
2. **Dado antigo deslocado não se corrige sozinho** — o fix do mapeamento não re-mapeia storage; usuário deve reimportar respondendo "Sobrescrever" no diálogo de duplicados.
3. **easy_localization (Flutter)**: `tr(args:)` NÃO interpola `{0}` — usar `namedArgs: {'count': ...}` + placeholder `{count}`. Confirmado com teste.
4. **Arquivos .dart do repo usam CRLF** — editar com `open(p, newline='').read().replace('\r\n','\n')` e gravar com `newline=''` após `.replace('\n','\r\n')`; replace cego corrompe.
5. **Electron preload/main só carregam no boot** — erro `No handler registered` = processo velho; reiniciar. `npm run dev` só sobe Vite; usar `npm run electron:dev`. HMR não recarrega preload.
6. **Inserir bloco no preload por âncora de texto** ("updater:") pode aninhar errado e SOBRESCREVER uma API existente (bug `media.check is not a function`) — validar estrutura com `node --check` e inspecionar o contexto da âncora antes.
7. **APK debug ≠ assinatura release** (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) — desinstalar antes de instalar debug (dados locais somem; usuário reimporta).
8. Testes com arquivos REAIS da igreja antes de declarar pronto (preferência explícita do Rafael).
9. **fakeIo de filesystem em testes: ACHAR a árvore por path completo (achatada)** — misturar lookup aninhado (`tree[p]` com chave composta) com árvore declarativa aninhada dá ENOENT silencioso: o walk recursivo entra no dir pai, `readdir` do filho lança, e o `catch {}` do walk ENGOLE o erro retornando vazio (scan "funciona" com 0 resultados). Fix: achar a árvore em paths completos num Map (`register('/', {dirs: def, files: {}})` com join normalizado) e instrumentar com log temporário quando der 0 resultados — o bug raramente está no módulo testado, está no helper.
10. **Redigir issues SEM crédito nominal** (regra Rafael 31/08): descrever como "caso real de usuário do Classo" / "igreja com 2+ usuários no Windows" — nunca nomear quem relatou.

## Espeçamento no ecossistema (specs no Obsidian)
- `00-Projects/PIANO/Importar-Liturgia-JA-Delphi.md`
- `00-Projects/PIANO/Itens-Agendados-Delphi.md`
- `00-Projects/PIANO/Port-Delphi-Ecossistema.md` (fases A–E: personaliz. projeção, cabo no APK, categorizar liturgias, tema configPT, pacote .louvorja)
- `00-Projects/PIANO/Adm-LouvorJA-Mapeamento.md` (API: /db/manifest MD5, version_number)

## Pendências conhecidas (não reimplementar do zero)
- Associação de arquivo .ja: desktop tem `fileAssociations` no package.json; FALTA handler open-file/second-instance + intent-filter Android.
- Export round-trip .ja/.xml pro Delphi (Fase 5) — gravar checked como data.

## Issues relacionadas ao armazenamento de mídia (30-31/08)
- **#142** — Classo reuso/migração (FASE 1 detecção implementada, ver abaixo).
- **#144** — mídia não compartilhada entre usuários Windows: cada usuário tem
  seu `AppData\Roaming\LouvorJA-PIANO` → segundo usuário baixa tudo de novo +
  erro de permissão. Proposta: mídia em `%PROGRAMDATA%\LouvorJA-PIANO\Media`
  (all-users, ACL modify p/ authenticated users), config/estado continua
  per-user, migração automática no primeiro boot. A FASE 2 da #142 e a #144
  mexem na mesma área — unificar migrações quando implementar.
- Pasta de mídia configurável (OneDrive/HD externo — pedido Caique, msgs
  4304/4306 grupo Dev): fase complementar da #144, não resolve o default
  multi-usuário sozinha.

## Paridade de MÍDIA com o Classo (pergunta recorrente de usuário, 30/08)Usuário do Classo (Delphi) pergunta se pode "copiar e colar" o conteúdo no PIANO.
Resposta correta hoje:
- Liturgia/agenda: importar via UI (`liturgy-ja-import.ts` lê `liturgia.ja`;
  `datapacket-parser.ts` lê os XML de itens agendados) — NÃO copiar arquivos.
- Áudio: PIANO guarda em `~/.config/LouvorJA-PIANO/Media/music/pt/<Álbum>/`
  (mesmo padrão de pastas-álbum do Classo), mas o casamento de áudio é pelo
  catálogo/`music_<id>.bin` da API, não pelo nome da pasta — copiar pasta é
  acaso de nomenclatura, não garantia. NÃO prometer copy-paste.
- Auto-detecção da instalação do Classo: **FASE 1 IMPLEMENTADA** (issue #142,
  PR #143, branch feat/classo-detect, commits 1b5bbad+f73bb50, 30/08/2026):
  - `electron/classo-detect.mjs` — detector puro: classoCandidatePaths
    (win32.join p/ determinismo em testes Linux), looksLikeClassoInstall
    (confirma via configPT.ja), scanClassoMedia (agrupa MP3 por pasta-álbum,
    máx. 2 níveis), findClassoDataFiles, detectClassoInstallation,
    probeClassoRegistry (`reg query` HKCU/HKLM Software\LouvorJA, nunca lança)
  - IPC `classo:detect` + `window.louvorja.classo.detect()` (ClassoApi no
    desktop-bridge é OPCIONAL — web não quebra)
  - `ClassoDetectCard.vue` em Settings → Mídia (a view era placeholder)
  - Spec: Obsidian `00-Projects/PIANO/Classo-Delphi-Reuso-Migracao.md`
  - FASE 2 pendente: reutilizar (link zero-cópia; player resolve local →
    externa → API), migrar (cópia com casamento fuzzy nome→ID do catálogo —
    NUNCA copiar sem casar), import assistido de .ja/XML pela wizard
    (reusar os parsers existentes).
- Associação de arquivo .ja (double-click abre o PIANO): desktop tem
  `fileAssociations` no package.json; FALTA handler open-file/second-instance
  + intent-filter Android.
