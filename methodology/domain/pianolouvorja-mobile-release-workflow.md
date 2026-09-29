# Pianolouvorja Mobile Release Workflow

> **Metodologia pública** — qualidade, versionamento, PR, release (semver por fases: v0.1 leitura, v0.2 escrita, v0.3 criação, v1.0). Aplica-se a qualquer stack.

---
Use quando houver mudança no `Piano-Louvor-JA-flutter`, receiver webOS/Android TV, multi-palco, ou pedido de versão/release.

## Fluxo obrigatório

1. Trabalhar em branch `feature/*`, `feat/*` ou `fix/*`.
2. Rodar `dart analyze` sem erros e testes focados antes de commit.
3. Rodar suíte completa quando possível; se falhar por ambiente, registrar causa real e não mascarar como falha de código.
4. Commit assinado (`git commit -S`) com Conventional Commits.
5. Push sem `--no-verify`.
6. Abrir PR feature → `staging` e solicitar revisão de Ezequias.
7. Só depois de CI verde e aprovação fazer merge em `staging`.
8. Versionar em commit separado conforme DEPLOY.md; criar PR `staging` → `main`.
9. Criar tag `vX.Y.Z` somente na linha aprovada. Workflow de release gera APK assinado e IPA unsigned.

Nunca criar release diretamente de branch feature não revisada.

## PRs independentes

Feature nova não deve carregar acidentalmente todos os commits de outra feature. Para PR dependente, basear explicitamente na branch anterior e documentar dependência. Para PR independente contra `staging`, começar de `origin/staging` e aplicar apenas os arquivos/commits da feature.

Quando CI encontra regressão causada por mudança recente, corrigir primeiro na branch/PR original. Depois abrir PR separado só para feature independente.

## CI e Rulesets

O workflow Flutter deve disparar em `push` e `pull_request` para `main`, `master` e `staging`. Gates mínimos:

- `flutter analyze --fatal-warnings`
- `flutter test`
- `flutter build apk --debug`
- build iOS debug quando runner macOS existir
- OSV/dependency scan

Branch protection pode ser Ruleset. API legada retornando 404 em `/branches/<branch>/protection` não prova ausência de proteção. Verificar:

```bash
gh api repos/OWNER/REPO/rulesets
 gh api repos/OWNER/REPO/rulesets/<id>
```

Confirmar especificamente se regras `required_status_checks` existem. Regra de PR + uma aprovação não torna CI obrigatório automaticamente.

Se mudar workflow para incluir `staging`, confirmar que checks aparecem no PR antes de configurar os nomes como obrigatórios.

## Diagnóstico de CI

Ler o log da execução, não inferir pela marca vermelha:

```bash
gh pr checks <N>
gh run view <RUN_ID> --log-failed
```

Quando `--log-failed` volta vazio (acontece), baixar o zip completo dos logs e garimpar localmente:

```bash
gh api "repos/OWNER/REPO/actions/runs/<RUN_ID>/attempts/1/logs" > /tmp/logs.zip
unzip -o -q /tmp/logs.zip -d /tmp/logs && grep -hE "##\[error\]" /tmp/logs/*.txt
```

### APK instalado ≠ código na branch (validação pós-fix, 06/09/2026)

Ciclo real: fix commitado + pushado, usuário testa e "não funciona" — mas o APK no device era das 00:52 e o commit das 06:23. O device NUNCA rodou o código corrigido. Antes de investigar bug de app, verificar os 3 relógios:

```bash
# 1. Quando o APK do device foi instalado
adb shell dumpsys package com.louvorja.louvorja_piano_mobile | grep lastUpdateTime
# 2. Quando o fix foi commitado
git log -1 --format="%ci" <sha>
# 3. Quando o APK local foi gerado
stat -c "%y" build/app/outputs/flutter-apk/app-release.apk
```

Se `lastUpdateTime` < horário do commit: rebuild com os dart-define atuais + `adb install -r`. Confirmar também o pacote certo no device — já houve dois pacotes coexistindo (`com.louvorja.piano.mobile` antigo vs `com.louvorja.louvorja_piano_mobile` novo); abrir o antigo reproduz exatamente os sintomas do bug.

E o checklist de versionamento que o usuário SEMPRE cobra ("ta versionado ta na pr ta no repo?"): commit existe ≠ pushado ≠ PR aberto. Verificar os três separadamente: `git status -sb` (ahead/behind), `git ls-remote origin <branch>` (sha idêntico ao local), `gh pr list --head <branch> --state open`. Se o PR não existe, criar — body via arquivo (`gh pr create --base staging --body-file /tmp/pr-body.md`) para evitar quebra de quoting em markdown com backticks inline.

### ADB wireless: pareamento por código (portas efêmeras)

A Depuração por Wi-Fi do Android usa portas efêmeras que mudam a cada ativação (5555 NÃO responde por padrão; a porta de conexão também morre quando o device sai do Wi-Fi, mas o entry mDNS sobrevive). Fluxo validado:

1. Usuário ativa Depuração por Wi-Fi e informa: porta de pareamento, porta de conexão e código (ex: `43903 38851 e 858053`).
2. `echo "<codigo>" | adb pair 192.168.1.10:<porta_pareamento>` — uma vez só; segunda chamada na mesma porta dá "protocol fault (couldn't read status message)" — é esperado, ignore (o pair já aconteceu).
3. `adb connect 192.168.1.10:<porta_conexao>` — depois disso o device aparece por mDNS (`adb-RQ8Y3006N9X-..._adb-tls-connect._tcp`) como `device` mesmo quando a porta TCP caiu ("No route to host"); usar o serial mDNS nos comandos seguintes.
4. adb não está no PATH do shell hermético: `export PATH=$PATH:~/Android/Sdk/platform-tools`.
5. Antes de cada sessão de captura: `adb logcat -c` e confirmar `lastUpdateTime` do pacote (seção acima).

Distinguir:

- código/análise: erro Dart, warning fatal
- teste: nome do teste e assertion
- ambiente: disco cheio, binding Flutter ausente, credential/setup
- workflow: trigger não inclui branch, job skipped, startup failure

### Armadilhas recorrentes de CI (verificadas em sessão real)

- **Path absoluto da máquina local em teste**: teste que lê arquivo real fora do repo (ex.: `/media/contribuidor/.../liturgia.ja`) passa na máquina do dev e falha no runner. Padrão do repo: guard `if (!File(path).existsSync()) { print('skip: arquivo ausente'); return; }` (igual `media_duration_reader_test`). Nunca committer path absoluto sem guard.
- **`org.gradle.java.home` em `android/gradle.properties`**: config de JDK da máquina do dev commitada quebra Build Android no runner (`Java home supplied is invalid`). JDK home NÃO vai no gradle.properties versionado — o CI configura Java via `actions/setup-java`.
- **Base do PR**: `Validate PR source branch` falha com "PRs para main só podem vir da branch staging". Se `gh pr edit <N> --base staging` parecer não surtir efeito, confirmar com `gh pr view --json baseRefName` e retargetar via API: `gh api -X PATCH repos/OWNER/REPO/pulls/<N> -f base=staging`. Após o retarget, o check "Validate PR source branch" fica VERMELHO ÓRFÃO no PR: o workflow só dispara para target=main (types: opened/synchronize/reopened — sem `edited`), então não revalida. Não bloqueia merge; confirmar com `mergeable:true` via API e ignorar o check órfão.
- **Regressão silenciosa offline-first**: chamar `getHymnDetails` incondicional no caminho de play local faz o `catch (_)` engolir a exceção e o play NUNCA acontecer sem rede — teste passa só com API no ar. Detail/metadata no caminho local é best-effort: try/catch próprio que só `rethrow` se não houver fonte local.

Exemplo recorrente: `SharedPreferences.getInstance()` chamado em `unawaited` durante teste sem binding pode gerar erro assíncrono. Encapsular persistência best-effort em `try/catch` e manter teste focado no comportamento.

## Multi-palco

Ao alterar roteamento:

- `StageSession` deve despachar por slot ativo/grupo espelho.
- Timer, áudio, vídeo, slides, pause e stop não podem chamar `_palco` diretamente se devem respeitar slot ativo.
- Stop global deve limpar todos os slots conectados.
- UI deve escutar `controller → slot → orchestrator → widget`; sem essa cadeia, status só atualiza ao reabrir sheet.
- Persistir IDs, nomes, portas e slot ativo; restaurar senders ao iniciar palco.
- Receiver webOS e Android TV precisam permanecer byte/paridade funcional; CI de receiver compara os arquivos.

## Flutter UI / player

NowPlaying aberto pelo hino e reaberto pelo mini player deve receber o mesmo contexto: detail completo com letra, capa, modo instrumental, source e duração. Não guardar só item resumido do catálogo; isso causa tela preta/sem letra ao reabrir.

### Termos e Privacidade = conteúdo real, nunca TODO (regra do projeto, 11/09)

Os ListTiles "Termos de Uso" e "Política de Privacidade" das Configurações ficavam mortos (comentário "Destino será ligado na Fase 6" — de OUTRO projeto). Regra: TODO visível na UI = bug. Implementar `TermsPage` estática embutida (offline-safe): Termos de Uso (uso do app, conteúdo da comunidade, conta, disponibilidade) + Política de Privacidade LGPD (dados coletados — e-mail/nome da conta custom, token no secure storage, retenção 30 dias, direitos do art. 18, menores de 16). Rotas nested go_router (`/settings/terms`, `/settings/privacy`); chave i18n `settings.privacyPolicy` nos 3 locales. Sem network: markdown/strings no próprio Dart.

Separar ações:

- minimizar: pop da página, sem pausar/parar player ou projeção;
- stop/X: para player local e todos receivers, limpa projeção e fecha página;
- mini player: reabre NowPlaying, não navega apenas para aba Hinos.

Feature de player deve preservar fluxo offline: faixa baixada não pode consultar API só para reconstruir metadata.

## Bíblia

Referência direta deve usar parser testável, não regex espalhada na UI. Aceitar `gn 1:1-3`, `genesis 2:3,5`, ranges mistos e acentos. Parser retorna livro, capítulo e lista normalizada. UI resolve livro por abreviação/nome/prefixo; Bloc aplica capítulo e seleção múltipla. Testar parser isoladamente e rodar testes de Bíblia.

### Filtro local antes da busca global

Não bloquear teste de Palco esperando índice global. O campo de filtro do capítulo aberto deve primeiro funcionar bem:

- texto livre filtra somente versos do capítulo atual;
- número exato filtra um verso;
- seletor sem livro/capítulo aceita `1-3`, `1,3,5` e `1,3-5` porque o contexto já está selecionado;
- ranges invertidos normalizam (`3-1` → 1,2,3);
- ao projetar múltiplos versos, formatar a referência: `[1,2,3]` → `Gênesis 1:1-3`; `[1,3,4,5]` → `Gênesis 1:1,3-5`.

Chevrons de navegação devem atualizar a seleção **e reprojetar automaticamente** o novo verso; não basta mudar estado no BLoC. Busca global entra depois, usando índice incremental do cache por versão, sem chamar API a cada tecla.

## Evidência mínima no relatório

Informar commits, URLs de PR, checks reais e limitações. Não dizer “release pronta” se só APK local foi gerado; release publicada exige tag/workflow e artefatos anexados.

Detalhes de comandos e falhas desta sessão: `references/ci-rulesets-and-multitarget.md`. Lições da sessão remote-v2 (path absoluto em teste, gradle JDK home, regressão offline-first, type-check do bridge): `references/session-2026-08-remote-v2-ci-fixes.md`. Sessão 2026-09 (custom auth + playlists + editor de músicas custom no APK: is_owner/Bearer, covers BMP, widget test com secure storage, progresso de download contextual, fallback chain com loop externo hosts×retries, editor v3.1 letra+timing, import .slja v3.2 com parser Dart, cover v3.3, semver por fases 0.3.0, disco cheio corrompendo arquivos): `references/session-2026-09-custom-auth-playlists.md`. Sessão 2026-09-11 tarde (.slja.zip no import, regras download/somente-leitura de coletânea, E2E custom contra API real com armadilhas de rotas/is_owner/audioUrl, migração SSD→HDD com symlinks + VACUUM do state.db sem downtime): `references/session-2026-09-11-slja-zip-e2e-hdd.md`.

### E2E custom contra API real (11/09/2026, commit b206d96)

Teste E2E em `test/e2e/custom_flow_e2e_test.dart` exercita a piano-api de dev no caminho completo: register → coletânea (`is_owner=1` só com bearer no `fetchCollections`) → upload multipart áudio+BG → `createMusic(idFileAudio:)` **antes das estrofes** (audio na criação, não depois) → 3 estrofes com timing + BG na capa → `fetchMusicDetail` → GET `/file/<url>` → terceiro sem token (`is_owner=0`, escrita 401) → cleanup. Guard de ambiente: ping na API no `setUpAll`; offline = skip, CI não quebra. Pegadinhas reais: `fetchCollections(bearerToken:)` sem token retorna `is_owner=0` para as próprias coletâneas; `detail.audioUrl` JÁ vem como URL completa (`_resolveFile` prefixa filesBaseUrl) — prefixar de novo dá 404; `removeMusicFromCollection` na verdade faz `DELETE /musics/{id}` (nome enganoso). Clientes órfãos de contas E2E anteriores ficam na API de dev — limpar por login com a senha conhecida do teste antes de rodar de novo.

### Noite de 11/09: playlists, offline-first, BG herdado, QA gate (commits 1626d31→f77bcc3, 876 testes)

- **PLAYLIST ≠ COLETÂNEA** (correção do o PO): playlist = seleção de hinos do acervo, local, sem API — port 1:1 do `playlist-storage.ts` do web pra Dart (`PlaylistStorage` em SharedPreferences, JSON camelCase compatível cross-plataforma — playlist do web abre no APK e vice-versa; anti toque-duplo de faixa consecutiva). Coletânea = conteúdo do usuário via API. Detalhes: skill `Piano-Louvor-JA-api` → `references/2026-09-11-playlists-bg-offline-first.md`.
- **Criar sem auth**: `LocalCustomStore` com ids negativos (não colidem com a API); FAB sempre visível; coletâneas locais no topo ("por Este dispositivo"); pitfall do store em memória (`_write` com clear+addAll do MESMO map apaga tudo — snapshot antes).
- **BG herda do 1º slide** com exceção individual (`effectiveSlideBg` puro em custom_lyric_slide.dart + upload deduplicado: N slides com a mesma imagem = 1 upload); salvar → timing recorder direto (sincronizar letra↔áudio, paridade com o editor web); modo local toca path do device (DeviceFileSource).
- **QA gate antes de PR** (processo novo acordado): skill `software-development/qa-agent` aprova antes do review do Ezequias. Subagents delegate estouram 600s em review grande — rodar gates por evidência local (grep/analyzer/test runner), subagent só pra fresh-eyes de arquivos específicos. Gap follow-up: `CustomMusicEditorPage` sem widget test.
- **CI**: `flutter analyze --fatal-warnings` cobre `test/` também — 3 unused imports em E2E novos derrubaram Analyze+Test; rodar o comando EXATO da CI localmente (incl. `--no-fatal-infos`) antes de pushar.

### Fim de noite 11/09: E2E crashando a CI + migração de ambiente + PRs congeladas (commits cc8a69f, 8d31028)

- **E2E "pula se API offline" com `late String token` CRASHA na CI em vez de pular**: no runner do GitHub a API de dev (IP local) é inalcançável, o setUpAll sai pelo catch e o guard `if (token.isEmpty)` acessa o late não-inicializado → `LateInitializationError` → 3 "failures" que localmente nunca aparecem (API sempre no ar no dev). Fix: `String? token` + local promotion (`final tok = token; if (tok == null || tok.isEmpty) return;`) — o analyzer não promove field de classe em closure async, então TODO uso posterior (bearerToken, tearDownAll, collectionId) usa o local, nunca o field. Padrão completo em `software-development/qa-agent` pitfalls 18-19.
- **E2E contra API viva pega bug de AMBIENTE**: o E2E de import falhou porque a migration `022_custom_auth_ownership.sql` nunca tinha sido aplicada no `data/catalog.db` de dev — `custom_musics` sem `owner_id` → POST musics retornava `{"error":"Erro ao criar música"}` (genérico, sem a causa). Os 874 testes mockados passavam todos. Fix: aplicar a migration do repo no DB de dev + checar `PRAGMA table_info` quando E2E falha só num ambiente. Diagnóstico rápido: o log da API local (`/tmp/piano-api.log` ou equivalente) mostrou o SqliteError exato — ler o log do SERVIDOR antes de caçar o cliente.
- **CI de PR velha falhando LEGADO**: PR #68 da API (aberta 10/09) falhava Lint & Format desde a criação (`let result;` → `noImplicitAnyLet` em custom.routes.ts:1402) e ninguém tinha visto. Reproduzir o comando EXATO da CI local (`npx biome ci src/ test/` — `check src/` NÃO é o mesmo escopo) antes de culpar o diff novo. Fix tipando: `let result: { lastInsertRowid: number | bigint };` (148/148 testes).
- **`git add -A` num repo com untracked de outras features incorpora lixo**: `.planning/bible/SPEC.md` + symlink `media` entraram num commit de lint fix e o push chegou a subir. Recovery: `git reset --soft HEAD~1` + restore staged, e como o push já tinha ido, `git push --force origin <branch>` do estado limpo (commit só teu, sem co-autores). Prevenção: addar arquivos EXPLÍCITOS, revisar `git status --short` antes.
- **`git fetch origin <branch>` não atualiza a ref local após force-push remoto**: `git log origin/<branch>..HEAD` continua mostrando 5 commits "à frente" fantasma. Forçar: `git fetch origin <branch>:refs/remotes/origin/<branch>`.
- **Estado final das 3 PRs (11/09)**: APK #54 (feat/custom-catalog), API #68 (feat/custom-auth), Palco #11 (feat/cloud-receiver) — todas com CI verde e prontas pro review do Ezequias.

### Regras de permissão custom ( produto, 11/09)

`.slja` E `.slja.zip` são aceitos no import (zip externo com o .slja dentro — WhatsApp anexa `.zip` na extensão; parser desembrulha e acha o .slja interno). Check verde de coletânea baixada é botão: tap = confirmar e remover download (`leaveCollection`, undo do `joinCollection`). Coletânea de terceiro: tap mostra "somente leitura" (nunca null silencioso); edição exclusiva do dono autenticado — 401 no servidor garante a regra mesmo se a UI mudar.

## Type-check do bridge Electron (app/web)

Quando o renderer consome API nova do preload (`remote.*`, `media.probeDuration`), declarar o tipo em `src/shared/types/desktop-bridge.ts` espelhando o `preload.mjs` real — nunca `@ts-expect-error` nem `any` implícito (CI roda `vue-tsc --build` com `noImplicitAny`). Padrão que funcionou: tipos `RemoteApi`/`RemoteBridgeMessage`/`RemotePairingInfo` derivados do preload + remote-server, campos opcionais quando o main nem sempre prove (`clientAddress?: string | null`). Mocks `vi.mock('@shared/services/desktop-bridge')` precisam exportar TODOS os símbolos usados pelo grafo de import (senão: "No X export is defined on the mock"). Em testes node (sem `localStorage`), mockar também `@shared/composables/useProjectionWindow` quando o store toca `syncProjection`. Valores de retorno `boolean | objeto | null` (ex.: `remoteSetVolume`) devem ser normalizados (`!== null`) antes de atribuir a boolean.
