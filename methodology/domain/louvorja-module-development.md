# LouvorJA Module Development

> **Metodologia pública** — como criar módulos (liturgia, hinos, bíblia). Aplica-se a qualquer stack.

---
Domain knowledge para criar modulos no app LouvorJA (Electron + Vue 3 + Vuetify).

## ⚠️ CRITICAL: Verify Module/PR Context BEFORE Acting

**O usuario corrigiu isso numa sessao anterior.** Quando o usuario menciona um PR ou modulo por numero/nome, SEMPRE verificar o que e ANTES de comecar a trabalhar. Nao assumir.

**Regra:** ABRIR a PR e ler titulo/body/files ANTES.

```bash
gh pr view <NUM> --repo elvieira/LouvorJA
```

Tambem verificar: o repo pode ser `elvieira/LouvorJA` (fork do Elias) ou `Piano-Louvor-JA/elias-louvorja` (fork do Rafael). Confirmar qual antes de checkout.

## Design System (ver `references/electron-design-tokens.md`) — NAO hardcoded cores, NAO Vuetify layout custom sidebar, SEMPRE dark mode + Electron antes de PR.

## ⚠️ CRITICAL: Electron Testing BEFORE PR (ZERO TOLERANCE)

**O usuario corrigiu isso DUAS VEZES** (sorteio + timer). NUNCA criar PR sem abrir o Electron e testar visualmente.

### Regra obrigatoria (nao negociavel):

1. **IMPLEMENT** — Codificar seguindo o plano
2. **TESTAR NO ELECTRON** — Abrir o app Electron, navegar ate o modulo, testar TODOS os fluxos (start/pause/reset, presets, projecao, etc.)
3. **Mostrar pro usuario** — O usuario PRECISA ver o modulo funcionando no Electron ANTES de qualquer PR
4. **So depois** — Commit + push + criar PR

### O que NAO fazer:

- **NUNCA criar PR sem testar no Electron** — "ta criou a pr mais nem abriu o app pra eu ver se deu certo"
- **NUNCA testar so no browser/Vue** — "vc mandou no vue e não no electro"
- **NUNCA pular a verificacao visual** — o build passar nao significa que funciona visualmente
- **Screenshots do Electron**: NUNCA usar `xdotool windowactivate` (crasha o Electron!), NUNCA `import -window <id>` (captura vazio por GPU compositing). Usar `import -window root` + crop com `convert`. Ver `references/help-module-implementation.md > Visual Testing & Screenshot Pitfalls`
- **NUNCA modificar `electron/main.js` sem reverter depois**: Se descomentar DevTools ou adicionar `remote-debugging-port`, SEMPRE reverter com `git checkout electron/main.js` antes de commitar. O PR deve conter apenas mudanças no modulo.

### Por que Electron e nao browser:

O Electron tem comportamento diferente do browser: janela popup de projecao, IPC, AppImage env, cache do Chromium. Coisas que funcionam no browser podem quebrar no Electron e vice-versa.

### Fluxo correto:

```
CODE -> npm run build -> abrir Electron -> testar visual -> mostrou pro usuario -> PR
```

Se o Electron nao tiver as deps configuradas no branch (sem script `electron:dev`), resolver ISS0 ANTES de criar o PR. Nao criar PR "e ja vai funcionar no Electron".

## MANDATORY: SDD + Project Excellence

Todo modulo novo DEVE seguir Spec-Driven Development:
1. **SPECIFY** — Escrever SPEC.md em `.hermes/specs/<module>-SPEC.md` (usar template em `templates/spec-template.md`)
2. **PLAN** — Quebrar em tasks bite-sized
3. **IMPLEMENT** — Codificar seguindo o plano
4. **TESTAR NO ELECTRON** — Abrir app, navegar ate modulo, testar todos fluxos, mostrar pro usuario
5. **VERIFY** — Build + review contra spec (DEPOIS do teste visual)

Nao pular a spec. "E so um modulo simples" NAO e desculpa. A spec garante que nao esquecemos RFs e que o PR tem descricao clara.

**Branch por modulo:** Cada modulo = 1 branch + 1 PR. Branch a partir de `upstream/electron` (NAO de `main` do fork -- `main` nao tem Electron). PR targeting `electron` no `elvieira/LouvorJA`.

**PITFALL -- branch base errada perde Electron**: O branch `main` do fork `Piano-Louvor-JA/elias-louvorja` (e do upstream `elvieira/LouvorJA`) NAO tem a pasta `electron/` nem o script `electron:dev`. Se voce criar um branch a partir de `main`, nao consegue rodar no Electron. Sempre criar a partir de `upstream/electron`:
```bash
git remote add upstream https://github.com/elvieira/LouvorJA.git  # se nao tiver
git fetch upstream
git checkout -b feature/<nome> upstream/electron
```
NUNCA: `git checkout -b feature/<nome> main`

## Arquitetura de Modulos

### Auto-discovery (NAO editar state.js)

O `ModuleManager.js` descobre modulos automaticamente via:
```
import.meta.glob("@/modules/**/index.js", { eager: true })
```

Isso inclui `src/modules/core/**/index.js` e `src/modules/**/index.js`. NAO e necessario registrar manualmente no `state.js` — o ModuleManager faz push automatico no `module_group` correspondente (baseado no `category` do manifest).

**PITFALL — CRÍTICO: Módulo não aparece na sidebar**: O `ModuleManager.installModule()` (linha 22) faz `if (!manifest.active) return;`. O `BaseModule` faz `active: manifest.active ?? true`, então `active` ausente = `true` (funciona). MAS o módulo ainda pode não aparecer na sidebar por dois motivos:

1. **`category` inexistente**: O `ModuleManager` faz push do módulo no `module_group[category].modules`. Se a categoria não existe no `module_group` do appdata, o módulo é registrado mas não aparece em nenhum grupo na sidebar. **Categorias válidas**: `utilities`, `musics`, `bible`, `core`, `developer`. NÃO inventar categorias como `"service"` ou `"tools"` — usar uma existente. Verificar `Sidebar.vue > moduleGroups()` para as categorias que aparecem (icons definidos em `groupIcons`).

2. **`showInMainMenu: true` obrigatório para módulos individuais**: Se o módulo não está num grupo (ou se quer que apareça também como item individual fora de grupo), PRECISA de `showInMainMenu: true` no manifest. Sem isso, `Sidebar.vue > individualModules()` filtra com `if (!groupedModuleIds.has(key) && module.showInMainMenu)` — módulos sem `showInMainMenu` são omitidos.

**Manifest mínimo que funciona** (módulo aparece na sidebar como item individual em Utilitários):
```json
{
  "id": "liturgy",
  "name": "Liturgia",
  "category": "utilities",
  "showInMainMenu": true
}
```
**NÃO omitir `showInMainMenu: true`** — sem isso, o módulo é instalado mas não aparece em nenhum lugar da sidebar (filtrado por `individualModules()` em `Sidebar.vue`). Descoberto na sessão do módulo Liturgia: o módulo compilava, instalava sem erros, mas não aparecia na sidebar porque faltava `showInMainMenu`.

**Debug**: Se o módulo não aparece, checar no DevTools Console:
```js
// Verificar se o módulo foi registrado
$appdata.get("modules.liturgy")
// Verificar grupos
$appdata.get("module_group")
// Verificar menu
$appdata.get("menu")
```

**PITFALL**: Se o manifest nao tiver `category`, o modulo NAO aparece em nenhum grupo. Categorias existentes: `core`, `utilities`, `media`, `developer`.

### Estrutura de Arquivos

```
src/modules/core/<nome>/
  manifest.json        # Obrigatorio
  index.js             # Obrigatorio (classe extends BaseModule)
  interface/Index.vue  # Obrigatorio (componente principal)
  interface/Popup.vue  # Opcional (projecao em segundo monitor)
  lang/pt.json         # Obrigatorio
  lang/es.json         # Obrigatorio
```

## Manifest (manifest.json)

```json
{
  "id": "sorteio",
  "name": "Sorteio",
  "version": "1.0.0",
  "description": "Descricao curta.",
  "author": "seu-username",
  "category": "utilities",
  "icon": "mdi-dice-multiple",
  "minAppVersion": "1.0.0"
}
```

Campos que o BaseModule adiciona automaticamente:
- `active`: `true` (padrao)
- `showInMainMenu`: `false` (padrao)
- `development`: `false` (padrao) — se `true`, so aparece quando `is_dev === true`
- `system`: `false`
- `overlay`: `false`
- `language`: `null`
- `translations`: merge dos lang/*.json

## index.js (Module Class)

```js
import BaseModule from "../../BaseModule";
import es from "./lang/es.json";
import pt from "./lang/pt.json";
import manifest from "./manifest.json";

export default class extends BaseModule {
  constructor() {
    manifest.translations = { pt, es };
    super(manifest);
  }
}
```

**PITFALL**: O caminho do BaseModule depende de onde esta o modulo. Para `src/modules/core/<nome>/`, use `../../BaseModule`. Para `src/modules/<nome>/`, use `../BaseModule`. **NÃO incluir extensão `.js`** — Vite/Rollup resolve automaticamente. Escrever `import BaseModule from "../../BaseModule"` (correto), NÃO `import BaseModule from "../BaseModule.js"` (quebra o build com `Could not resolve "../BaseModule.js"`). Subagentes que escrevem código repetidamente cometem este erro — sempre validar o import path no build antes de continuar.

## Index.vue (Componente Principal)

### Pattern Obrigatorio: l-window (Options API)

Modulos core usam `<l-window>` como wrapper principal (de `@/components/Window.vue`). NAO usar `v-slide-y-reverse-transition` -- esse pattern e para modulos antigos fora de `core/`.

```vue
<template>
  <l-window
    v-model="module.show"
    :title="t('title')"
    :icon="module.icon"
    closable
    minimizable
    @close="close()"
    @minimize="$modules.minimize(module_id)"
    @resize="resize"
    :index="show ? 1 : 0"
  >
    <template v-slot:customize>
      <l-customization-tools :module="module" />
    </template>

    <template v-slot:header-extra>
      <LScreenBtn module="<module_id>" />
    </template>

    <div class="module-container pa-4">
      <!-- seu conteudo aqui -->
    </div>
  </l-window>
</template>

<script>
import manifest from "../manifest.json";
import LWindow from "@/components/Window.vue";
import LScreenBtn from "@/components/buttons/Screen.vue";
import LCustomizationTools from "@/components/CustomizationTools.vue";

export default {
  name: "<Module>IndexPage",
  components: { LWindow, LScreenBtn, LCustomizationTools },
  computed: {
    /* COMPUTEDS OBRIGATORIOS - INICIO */
    module_id() { return manifest.id; },
    module() { return this.$modules.get(this.module_id); },
    /* COMPUTEDS OBRIGATORIOS - FIM */
    show() { return this.module ? this.module.show : false; },
  },
  methods: {
    t(key) { return this.module && this.module.t ? this.module.t(key) : key; },
    close() { this.$modules.close(this.module_id); },
    resize() { /* noop or custom */ },
  },
};
</script>
```

**PITFALL**: NAO usar `ModuleContainer` de `@/layout/ModuleContainer.vue` -- esse arquivo **EXISTE mas nao e o wrapper correto para modulos core**. O wrapper correto e `LWindow` de `@/components/Window.vue`. O `ModuleContainer` e usado para modulos nao-core (ex: clock em `src/modules/clock/`). Modulos em `src/modules/core/` devem usar `LWindow`.

### TRES PADROES DE LAYOUT (escolher pelo tipo de modulo)

**Pattern A — Janela flutuante minimizável (`l-window`)**: Para modulos que precisam ser minimizáveis e flutuantes (bible). Usa `<l-window>` de `@/components/Window.vue` com slots `customize` e `header-extra`.

**Pattern B — Full-page grid 2 colunas — PREFERIDO PARA MÓDULOS NOVOS**: Para módulos que ocupam toda a área de conteúdo (Sorteio, Timer). O Sorteio (PR #39) é a **REFERÊNCIA DE LAYOUT**. O usuário corrigiu isso explicitamente:
