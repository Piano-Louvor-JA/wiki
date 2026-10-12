# Systematic Debugging

> **Metodologia pública** — 4-phase root cause debugging. Aplica-se a qualquer stack.

---
## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

**Violating the letter of this process is violating the spirit of debugging.**

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## When to Use

Use for ANY technical issue:
- Test failures
- Bugs in production
- Unexpected behavior
- Performance problems
- Build failures
- Integration issues

**Use this ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes
- Previous fix didn't work
- You don't fully understand the issue

**Don't skip when:**
- Issue seems simple (simple bugs have root causes too)
- You're in a hurry (rushing guarantees rework)
- Someone wants it fixed NOW (systematic is faster than thrashing)

## The Four Phases

You MUST complete each phase before proceeding to the next.


## Phase 2: Pattern Analysis

**Find the pattern before fixing:**

### 1. Find Working Examples

- Locate similar working code in the same codebase
- What works that's similar to what's broken?

**Action:** Use `search_files` to find comparable patterns:

```python
search_files("similar_pattern", path="src/", file_glob="*.py")
```

### 2. Compare Against References

- If implementing a pattern, read the reference implementation COMPLETELY
- Don't skim — read every line
- Understand the pattern fully before applying

### 3. Identify Differences

- What's different between working and broken?
- List every difference, however small
- Don't assume "that can't matter"

### 4. Understand Dependencies

- What other components does this need?
- What settings, config, environment?
- What assumptions does it make?

---

## Phase 3: Hypothesis and Testing

**Scientific method:**

### 1. Form a Single Hypothesis

- State clearly: "I think X is the root cause because Y"
- Write it down
- Be specific, not vague

### 2. Test Minimally

- Make the SMALLEST possible change to test the hypothesis
- One variable at a time
- Don't fix multiple things at once

### 3. Verify Before Continuing

- Did it work? → Phase 4
- Didn't work? → Form NEW hypothesis
- DON'T add more fixes on top

### 4. When You Don't Know

- Say "I don't understand X"
- Don't pretend to know
- Ask the user for help
- Research more

---

## Phase 4: Implementation

**Fix the root cause, not the symptom:**

### 1. Create Failing Test Case

- Simplest possible reproduction
- Automated test if possible
- MUST have before fixing
- Use the `test-driven-development` skill

### 2. Implement Single Fix

- Address the root cause identified
- ONE change at a time
- No "while I'm here" improvements
- No bundled refactoring

### 3. Verify Fix

```bash
# Run the specific regression test
pytest tests/test_module.py::test_regression -v

# Run full suite — no regressions
pytest tests/ -q
```

### 4. If Fix Doesn't Work — The Rule of Three

- **STOP.**
- Count: How many fixes have you tried?
- If < 3: Return to Phase 1, re-analyze with new information
- **If ≥ 3: STOP and question the architecture (step 5 below)**
- DON'T attempt Fix #4 without architectural discussion

### 5. If 3+ Fixes Failed: Question Architecture

**Pattern indicating an architectural problem:**
- Each fix reveals new shared state/coupling in a different place
- Fixes require "massive refactoring" to implement
- Each fix creates new symptoms elsewhere

**STOP and question fundamentals:**
- Is this pattern fundamentally sound?
- Are we "sticking with it through sheer inertia"?
- Should we refactor the architecture vs. continue fixing symptoms?

**Discuss with the user before attempting more fixes.**

This is NOT a failed hypothesis — this is a wrong architecture.

---

## Red Flags — STOP and Follow Process

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run tests"
- "Skip the test, I'll manually verify"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [lists fixes without investigation]"
- Proposing solutions before tracing data flow
- **"One more fix attempt" (when already tried 2+)**
- **Each fix reveals a new problem in a different place**

**ALL of these mean: STOP. Return to Phase 1.**

**If 3+ fixes failed:** Question the architecture (Phase 4 step 5).

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern, don't fix again. |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence, trace data flow | Understand WHAT and WHY |
| **2. Pattern** | Find working examples, compare, identify differences | Know what's different |
| **3. Hypothesis** | Form theory, test minimally, one variable at a time | Confirmed or new hypothesis |
| **4. Implementation** | Create regression test, fix root cause, verify | Bug resolved, all tests pass |


## Real-World Impact

From debugging sessions:
- Systematic approach: 15-30 minutes to fix
- Random fixes approach: 2-3 hours of thrashing
- First-time fix rate: 95% vs 40%
- New bugs introduced: Near zero vs common

**No shortcuts. No guessing. Systematic always wins.**

## Pitfall: Fixing the wrong handler in dual-router projects

**Pattern:** Projects that have two API routing systems (legacy + new framework) can trick you into fixing the wrong handler. Your fix compiles, passes all tests, but never executes in production because the frontend hits a different route.

**Example:** Next.js App Router (`src/app/api/srs/route.ts`) + legacy Vercel serverless catch-all (`api/[...route].js`). Frontend POSTs to `/api/atividades` → legacy handler. You fix the App Router handler → dead code.

**How to detect this BEFORE fixing:**
1. **Trace the fetch URL.** Read the frontend code that makes the API call. What exact URL does it use?
2. **Check which routing system handles that URL.** In Next.js: does it match an `src/app/api/*/route.ts`? Or does it fall through to a catch-all?
3. **Check server logs.** If the server logs `[API Router] Request:` → legacy handler. No such log → App Router.
4. **Console.log the URL.** In `apiFetch`, add `console.log(url.toString())` to see the ACTUAL URL being called. You may find the query params are wrong.

**Rule:** If a fix passes tests but the user says "still broken", your first question should be: "Am I fixing the code that actually runs?"

## Pitfall: searchParams key/value confusion

**Pattern:** `URLSearchParams.append(key, value)` where you accidentally swap key and value. Creates `?srs=` instead of `?type=srs`.

**Why it's deadly:**
- No error thrown — the URL is technically valid
- Backend reads `req.query.type` → `undefined` → all type-based routing fails silently
- Frontend may show optimistic UI so the user doesn't immediately notice
- The `400 Operação inválida` response may be swallowed by error handling

**Detection:** Always verify constructed URLs with `console.log(url.toString())` or curl before relying on query params for routing.

## Pitfall: Next.js import.meta.url breaks path resolution in production

**Pattern:** Code that derives `__dirname` from `import.meta.url` and resolves relative paths (e.g. `resolve(__dirname, "../../..")`) works in dev but breaks in production (`next start`). In production, bundled code has `import.meta.url` pointing to `process.cwd()`, not the original source file. Paths resolve to `/` or wrong directories.

**Why it's deadly:**
- No error thrown — files get written to wrong paths silently
- Works perfectly in `next dev` (source file location is correct)
- Only manifests in Docker/production where the build output differs
- PDF/image generation "succeeds" but files are unreachable

**Detection:** Run inside container:
```bash
docker exec <c> node -e "import{resolve as r,dirname as d}from'node:path';import{fileURLToPath as f}from'node:url';console.log(r(d(f(import.meta.url)),'../../..'))"
```
If output is `/` instead of the project root, this is the bug.

**Fix:** Check if `__dirname` has `/src/` in path (dev) vs not (production), then fall back to `process.cwd()`:
```ts
const ROOT = __dirname.includes("/src/") ? resolve(__dirname, "../../..") : process.cwd();
```

## Pitfall: Next.js App Router static rendering caches stale DB data at build time

**Pattern:** Pages that read from a database (via server components) without `export const dynamic = "force-dynamic"` get statically rendered at `next build`. The rendered HTML/RSC payload is frozen forever. If the DB had a "running" task at build time, the page will show "Engine Running" and disable buttons permanently — even after the task finishes or fails.

**Why it's deadly:**
- No error thrown — the page renders fine with stale data
- `isRunning` derived from cached data makes UI elements permanently disabled
- Developers assume the issue is in the action handler, not the rendering
- Rebuilding the container re-caches whatever the DB state is at that moment

**Detection:**
1. Check if the page has `export const dynamic = "force-dynamic"` or `export const revalidate = 0`
2. If missing, the page is statically rendered — data is baked into the build
3. Form `action=""` in DOM is normal for RSC server actions (they use the RSC protocol, not traditional form actions)

**Fix:** Add `export const dynamic = "force-dynamic"` to any page that reads from a DB or external data source.

## Pitfall: Production 500 errors with masked error messages

**Pattern:** Production error handlers catch errors and return generic `"Internal Server Error"` messages (no stack trace, no error details). This is correct for security but makes it impossible to diagnose the root cause from the HTTP response alone. Sentry/monitoring may not be configured, and Vercel function logs can be delayed or filtered.

**Technique — Temporary debug middleware:**
When you have 500s in production but no observability, modify the error handler to include the real error message in the response body temporarily:
```ts
// BEFORE (secure but opaque):
const message = isProduction ? 'Erro interno.' : error.message;

// TEMPORARY DEBUG (revert after fixing!):
const message = isProduction ? `Erro interno. [DEBUG: ${error.message}]` : error.message;
```
Deploy this, trigger the failing endpoint from the browser, and read the actual error from the JSON response. Then you get the exact SQL error (column name, constraint name, etc.) without needing Sentry.

**Critical:** This exposes internal error details publicly. MUST be reverted immediately after identifying the root cause. Commit message should say "debug: temporarily..." and the revert commit should be in the same PR/push.

**When to use:** No Sentry, no accessible server logs, and the error only reproduces in production (local dev works fine because schema differs).

**Alternative — Vercel CLI for production logs:**
If you have access to the Vercel CLI and the project is linked, fetch error logs directly:
```bash
vercel logs --level error --since 24h --limit 100 --expand
```
The `--expand` flag shows full error details including SQL error messages and stack traces. This avoids modifying production code for debugging.
Use `vercel link` first to link the local repo to the Vercel project, then fetch logs with time filters (`--since 1h`, `--since 24h`) and level filters (`--level error`, `--level warning`).

**Alternative:** If you have direct DB access, run the SQL query directly to check column/constraint names:
```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'my_table';
SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'my_table'::regclass;
```

## Pitfall: SQLite CURRENT_TIMESTAMP in dynamically-built SQL

**Pattern:** Using template literals to build SQL where a variable resolves to the string `"CURRENT_TIMESTAMP"`. SQLite interprets it as a column identifier, not the built-in keyword.

**Why it's deadly:**
- Only fails for certain parameter combinations (e.g., when `status === "applied"`)
- Error says "no such column" which makes you think the schema is wrong
- The same SQL keyword works fine when hardcoded — only breaks via interpolation

**Detection:** If you see `no such column: CURRENT_TIMESTAMP`, search for template-literal SQL that conditionally injects the keyword as a string variable.

**Fix:** Use explicit branching with separate prepared statements instead of dynamic column interpolation.

## Pitfall: Test files in unexpected locations after query signature changes

**Pattern:** When you change SQL query signatures (e.g., removing columns from INSERT), you update the main test file for that route. But there may be a SECOND test file that imports and tests the same route from a different describe block (e.g., `atividades-learning.test.ts` testing SRS alongside other learning features). That file's mocks still reference the old column names.

**Detection:** Run the FULL test suite after changing query signatures, not just the route-specific test file. A quick `vitest run 2>&1 | grep "FAIL"` catches all failures at once.

**Lesson:** Before declaring "all tests pass," always run the full suite. Per-file runs only verify the file you changed, not files that share imports.

## Pitfall: LLM API responses wrapped in markdown code blocks

**Pattern:** When calling LLM APIs (OpenRouter, OpenAI, etc.) with instructions to return JSON, models often wrap the response in `\`\`\`json...\`\`\`` markdown code blocks despite explicit instructions to return raw JSON.

**Why it's deadly:**
- `JSON.parse()` throws SyntaxError on the backtick markers
- In server actions / API handlers, this error is often caught silently and returns `undefined`
- UI shows no feedback — buttons appear "dead" with no error message
- The LLM's response is otherwise perfectly valid JSON

**Detection:** If a button/action "does nothing" after an AI call, log the raw response before parsing. Look for `\`\`\`json` at the start.

**Fix:** Strip markdown fences before every `JSON.parse()` of AI content:
```typescript
function parseAIResponse<T>(content: string): T {
  const cleaned = content
    .replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();
  return JSON.parse(cleaned) as T;
}
```

Apply EVERYWHERE AI content is parsed — search for `JSON.parse` near any LLM API call. This is especially common with models like Z.ai `glm-5.1`, but can happen with any model.

**Companion pitfall:** AI responses have unpredictable structure. Always validate with type guards before property access (`if (!result?.field) throw new Error("AI missing field")`), not direct destructuring that crashes on `null`.

## Pitfall: CSS Cascade Priority — Unlayered CSS overrides Tailwind utilities

**Pattern:** Global CSS resets (unlayered) override Tailwind utility classes (layered). CSS without `@layer` has HIGHER priority than CSS in Tailwind's `base`, `components`, or `utilities` layers.

**Example from Tesouros Portal:**
- `games.css` has `* { padding: 0 }` and `* { margin: 0 }`
- Quiz page has elements with `p-4`, `mt-12`, `mb-8` classes
- Computed styles show `padding: 0px` and `margin: 0px` despite Tailwind classes
- Buttons and sections appear squashed together

**Why it's deadly:**
- No build error — CSS is valid syntax
- Linter doesn't catch it — selector specificity is correct (`*` vs class)
- Tailwind docs don't mention unlayered CSS priority issue
- You waste hours debugging Tailwind when the problem is CSS cascade

**Root cause:**
```
Tailwind Preflight (@layer base):
  * { margin: 0; padding: 0; }
  .mt-12 { margin-top: 3rem; }

Your CSS (unlayered, loads after Tailwind):
  * { margin: 0; padding: 0; }
```

Result: Unlayered CSS wins, `.mt-12` is overridden.

**Detection:**
1. Open DevTools Elements panel
2. Select element with Tailwind class (e.g., `mt-12`)
3. Check Computed Styles:
   - If `margin-top: 0px` despite `.mt-12` class → unlayered override
4. Check Styles panel for `*` rule overriding utility

**Fix strategies:**

1. **Remove conflicting resets** (preferred when Tailwind Preflight covers it):
```css
/* REMOVED — let Tailwind Preflight handle it */
/* *, *::before, *::after { margin: 0; padding: 0; } */

/* Keep only custom resets not in Tailwind */
*, *::before, *::after {
  box-sizing: border-box;
}
```

2. **Wrap in Tailwind layer** (if you need custom reset):
```css
@layer base {
  *, *::before, *::after {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }
}
```

3. **Increase utility specificity** (last resort, avoid):
```css
.g-mt-12 {
  margin-top: 3rem !important;
}
```

**Prevention:**
- Never use `* { margin/padding: 0 }` in component-scoped CSS files
- Check if Tailwind Preflight already provides the reset you need
- Use `@layer base` for global styles that should have lower priority than utilities
- Audit computed styles when Tailwind utilities don't apply

**Reference files**

- **`references/nextjs-cypress-e2e.md`** — Next.js + Cypress E2E debugging: React hydration mismatches, self-fetch SSR anti-pattern, env var baking, params API version trap, workflow best practices. Load when debugging Cypress/Playwright E2E failures in Next.js projects.
- **`references/nextjs-docker-server-actions.md`** — Next.js App Router + Docker: debugging server actions that spawn CLI processes. 11 root causes chain (static cache, spawn cwd, build context, DB path, import.meta.url, Playwright X11, CLI LIMIT, volume path, Turbopack PATHS inlining, server action timeouts, SQLite CURRENT_TIMESTAMP interpolation). Includes curl-based testing technique for React 19 server actions with correct content-type and action ID resolution. Load when Fleet Control Center / dashboard buttons don't work, file API returns 404, or SQL errors mention "no such column: CURRENT_TIMESTAMP".

## Pitfall: Conditional side-effects gated behind unrelated business logic

**Pattern:** A function performs two independent operations — one conditional (award XP only if eligible) and one unconditional (mark mission complete). The unconditional operation is accidentally gated behind the conditional one's result.

**Example:**
```typescript
// BUG: completeDailyMission only called when XP > 0
if (result.shared) {
  await completeDailyMission(userId, clubeId, 'share_achievement');
}
```
User already shared today → no XP bonus → `shared = false` → mission never completes. The mission completion is a side-effect of the user's ACTION (they shared), not a side-effect of the XP REWARD (they got bonus XP).

**Why it's deadly:**
- Works correctly on first use (XP > 0, both fire)
- Silently breaks on repeat use (XP = 0, neither fires)
- No error thrown — the mission just stays "incomplete"
- The code looks logically correct at first glance

**Detection:** When a feature "works once but not twice" or "works for new users but not existing", check if a side-effect is gated behind a first-time-only condition.

**Fix:** Decouple the two concerns. Each operation should execute independently:
```typescript
// XP award (conditional)
const result = await awardShareXP(client, userId, ...);

// Mission completion (unconditional, non-blocking)
await completeDailyMission(userId, clubeId, 'share_achievement').catch(() => {});
```

**General rule:** If a user action should always produce effect X, never gate X behind a conditional check for effect Y. They are separate concerns even if they often fire together.

## Pitfall: TypeScript @ts-ignore vs @ts-expect-error for TS6133

**Pattern:** You need to suppress TS6133 (`'X' is declared but its value is never read`) for a method or variable that's intentionally unused (future code, dead code elimination target, etc.). You try `@ts-expect-error` — it doesn't work. You try `biome-ignore` — it doesn't work either.

**Why:** `@ts-expect-error` only suppresses TYPE errors (TS2xxx, TS7xxx). TS6133 is a "lint-style" check from `noUnusedLocals`/`noUnusedParameters` in `tsconfig.json` — `@ts-expect-error` explicitly does NOT cover it. `biome-ignore` only suppresses Biome lint rules, not TypeScript compiler checks. They are separate systems.

**What works:**
```typescript
// ✅ @ts-ignore suppresses TS6133
// @ts-ignore TS6133: will be wired in next iteration
private async _navigateToNextModule(levelIdx: number, moduleIdx: number) {

// ❌ @ts-expect-error does NOT suppress TS6133 (causes "Unused '@ts-expect-error' directive")
// @ts-expect-error
private async _navigateToNextModule(levelIdx: number, moduleIdx: number) {

// ❌ biome-ignore does NOT suppress TS errors
// biome-ignore lint/suspicious/noUnusedPrivateClassMembers: reason
private async _navigateToNextModule(levelIdx: number, moduleIdx: number) {
```

**Detection:** If `@ts-expect-error` produces "Unused '@ts-expect-error' directive", the error code is not a type error — switch to `@ts-ignore`.

**tsc -b vs tsc --noEmit:** `tsc -b` (build mode) uses project references and may be less strict than `tsc --noEmit`. A project can pass `tsc -b` with zero errors while `tsc --noEmit` shows pre-existing errors in source files. When the patch tool's lint check shows errors but `tsc -b` passes, the errors are from `--noEmit` mode — verify with both commands before concluding.

| Directive | Suppresses type errors (TS2xxx) | Suppresses TS6133 (unused) | Suppresses Biome lint |
|-----------|--------------------------------|---------------------------|----------------------|
| `@ts-ignore` | Yes | Yes | No |
| `@ts-expect-error` | Yes | No | No |
| `biome-ignore` | No | No | Yes |

## Pitfall: Duplicate instances in Chrome Extension content scripts

**Pattern:** Every action/log appears EXACTLY TWICE with identical timestamps. Progress exceeds 100% (e.g., 320% = 32/10). Navigation loops because two independent orchestrators compete.

**Root cause:** A module exports both a class AND a module-level instantiated singleton (`export const x = new X()`). When the entry point imports the class, module evaluation triggers the singleton as a side-effect (Instance A). The entry point then creates its own instance (Instance B). Both run simultaneously on the same page.

**How to diagnose:**
1. Look for DUPLICATE log entries at identical timestamps — this is the smoking gun
2. Search for `new ClassName()` across all non-test source files: `grep -rn 'new ClassName' src/ --include='*.ts' | grep -v '.test.'`
3. If the class is instantiated in both a module-level export AND the entry point → confirmed

**Fix:** Remove the module-level instantiation. Entry point should be the ONLY place that creates the orchestrator. Tests create their own instances in `beforeEach`.

**Why it's deadly:** Each instance has independent `isProcessing` flags and retry timers. Debouncing within one instance doesn't prevent the other from firing. The two instances process the same lessons, doubling progress counters, and their navigation calls conflict causing loops.

## Technique: MCP Chrome DevTools for DOM-dependent bug diagnosis

**When to use:** Debugging scrapers, browser extensions, or any code that depends on specific DOM structure (CSS selectors, element hierarchy, text content). Particularly effective when the user reports a bug on a live site but you can't reproduce the DOM locally.

**Phase 1 investigation steps:**

1. **Navigate to target page** — `mcp_chrome_devtools_navigate_page` to the exact URL where the bug occurs
2. **Take accessibility snapshot** — `mcp_chrome_devtools_take_snapshot` → full DOM tree with roles, text content, UIDs
3. **Run JavaScript to verify selectors** — `mcp_chrome_devtools_evaluate_script` with functions that:
   - Count matches for each CSS selector used in source code
   - Sample text content from matched elements
   - Walk the DOM chain from target elements to understand container structure
4. **Cross-reference with source** — Compare selector match counts with what the code expects. Zero matches on a critical selector = root cause found.

**Example diagnostic script:**
```javascript
() => {
  // Check if the code's selectors actually find elements
  const spans = document.querySelectorAll("span");
  const nivelSpans = [];
  spans.forEach(s => {
    const text = s.textContent?.trim() || "";
    if (text.match(/^Nível\s+\d+$/i)) {
      nivelSpans.push({ text, cls: s.className?.substring(0, 60) });
    }
  });
  
  // Check module links
  const moduleLinks = document.querySelectorAll("a[href*='/sala/']");
  
  return {
    nivelSpans,
    moduleLinkCount: moduleLinks.length,
    h2Count: document.querySelectorAll("h2").length
  };
}
```

**Why this beats reading source code alone:** You can trace the ACTUAL DOM hierarchy (parent chain, sibling structure, data attributes) that the selectors must match. Selectors that "look correct" in isolation may fail because the expected parent/child relationship doesn't exist, or elements have unexpected wrapper divs.

**Cross-reference technique:** Run the SAME selectors from source code in `evaluate_script`. If `document.querySelectorAll("h2, button span.text-lg")` returns 0 on the level page but `document.querySelectorAll("span")` filtered by textContent returns 5 matches → the selectors need updating, not the page structure.

## Pitfall: SELECT/UPDATE WHERE clause mismatch — phantom state

**Pattern:** A GET endpoint filters rows by date (`WHERE created_at::date = today`) but the corresponding UPDATE/DELETE uses a broader filter (`WHERE user_id = $1 AND key = $2`). If the user has stale rows from previous days, the UPDATE modifies the WRONG row (oldest match). The frontend refetches with the date filter → today's row still shows as incomplete. The user sees "mission not completing" despite clicking the correct button.

**Why it's deadly:**
- Works correctly for users with no stale data (clean state)
- Only manifests when rows from previous days exist with `completed_at IS NULL`
- No error thrown — UPDATE succeeds (returns affected row count > 0)
- The "fixed" row is invisible to the frontend (different date)
- The real row stays broken silently

**Detection:**
1. User reports "I clicked X but status didn't change"
2. Check if the read query and write query use IDENTICAL WHERE clauses
3. If read adds `date = today` but write doesn't → confirmed
4. Query the DB directly: `SELECT id, created_at::date, completed_at FROM table WHERE key = 'X' ORDER BY created_at`

**Fix:** Ensure write queries include ALL filters from the read query:
```typescript
// READ (frontend sees this):
WHERE user_id = $1 AND clube_id = $2 AND created_at::date = $3

// WRITE (must match):
WHERE user_id = $1 AND clube_id = $2 AND mission_key = $3 AND completed_at IS NULL
  AND created_at::date = $4  -- THIS WAS MISSING
```

**General rule:** When a table accumulates daily rows and the UI shows only "today's" data, EVERY mutation (UPDATE/DELETE) must include the same date filter as the SELECT. Otherwise mutations can target invisible rows.

## Pitfall: "Column does not exist" in production — code vs DB schema mismatch

**Pattern:** Code references a column name that doesn't exist in the production database. The error is `42703: column "X" does not exist`. Often the column name in code was chosen based on variable names or conceptual naming, not the actual schema.

**Why it's common:** Dev and prod databases can drift. A developer writes SQL referencing a column by a different name than what was created. If dev DB was recreated at some point with the "wrong" name too, everything passes locally. Only prod crashes.

**Phase 1 investigation technique:**
```sql
-- Verify actual column names BEFORE writing any SQL fix
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'your_table'
ORDER BY ordinal_position;
```

Compare the output against every column name in your SQL queries. The error message's `position` field tells you the character offset of the offending column in the query.

**Common variant:** Code uses an alias like `SELECT wrong_name AS correct_name`. This reads the non-existent column first (crash), then aliases it. The alias direction is inverted — should be `SELECT correct_name AS wrong_name` if frontend expects the wrong name, or better yet fix the frontend to use the real column name.

**Fix:** Align code to the actual DB schema, not the other way around. Renaming production columns requires a migration with downtime risk; fixing code is instant and safe.

**Prevention:** When adding SQL queries to a route, always verify the table schema first. Never assume column names from code variable names, other developers' comments, or previous pitfall notes that may themselves be wrong.

## Pitfall: Off-by-one in same-transaction INSERT → COUNT

**Pattern:** Code does `INSERT INTO table` then `SELECT COUNT(*) FROM table WHERE today` in the same DB transaction, then adds `+ 1` to the count assuming the INSERT isn't visible yet. But PostgreSQL sees the INSERT immediately within the same transaction — the `+ 1` double-counts.

**Why it's deadly:**
- Works correctly for count=0 → 0+1=1 (first time, threshold not met)
- Silently triggers at N-1 instead of N (e.g., "3 quizzes" completes after 2)
- No error thrown — the logic is "correct" in isolation, just the offset is wrong
- Only manifests in production data (unit tests with mocked DB won't catch it)

**Detection:**
1. Mission/threshold triggers earlier than expected
2. Check if INSERT happens before COUNT in the same transaction/client
3. If yes, COUNT already includes the inserted row — no `+ 1` needed

**Fix:** Remove the `+ 1` if INSERT precedes COUNT. If COUNT precedes INSERT, the `+ 1` is correct.

**Verification technique — Timeline reconstruction:**
Query production DB with `AT TIME ZONE 'America/Sao_Paulo'` to reconstruct the exact sequence:
```sql
-- Reconstruct event timeline for a specific user/day
SELECT (created_at AT TIME ZONE 'America/Sao_Paulo')::text as sp_time
FROM quiz_completions
WHERE user_id = 3
  AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = '2026-05-21'
ORDER BY created_at;

-- Cross-reference with mission completion times
SELECT mission_key, (completed_at AT TIME ZONE 'America/Sao_Paulo')::text
FROM daily_missions
WHERE user_id = 3 AND completed_at IS NOT NULL
  AND (created_at AT TIME ZONE 'America/Sao_Paulo')::date = '2026-05-21'
ORDER BY completed_at;
```

This technique (timeline reconstruction via timezone-aware production queries) is the fastest way to diagnose "completed too early" bugs. Compare actual data counts against the threshold to find the exact offset.

## Pitfall: Investigating a bug that's already been fixed

**Pattern:** User reports a production error from logs. You launch a full investigation (spike, schema introspection, dependency analysis) without checking git history first. After significant effort, you discover the fix was already committed and deployed — the error timestamp was BEFORE the deploy.

**Why it happens:**
- Error logs show timestamps, not fix status
- The excitement of "interesting error" bypasses the boring "check recent commits" step
- The spike skill's decomposition step feels productive but skips the most basic check

**The 30-second check that prevents wasted effort:**
```bash
# BEFORE any investigation:
git log --oneline -10

# BEFORE deploying a fix:
gh api repos/{owner}/{repo}/deployments --jq '.[0:3] | .[] | {environment, sha: .sha[0:7], created_at}'
```

Compare the error timestamp to the most recent deployment. If the deploy SHA is newer than the error, the fix may already be live. If `git log` shows a commit mentioning the exact error, you're done.

**Rule:** When a production error is reported, the order of operations is:
1. `git log --oneline -10` — is it already fixed?
2. Check deployment timestamps — is the fix deployed?
3. ONLY THEN start investigation if no fix exists

This is a specialization of Phase 1 Step 3 ("Check Recent Changes") — specifically: always check if the bug is ALREADY FIXED before launching a new investigation.

## Pitfall: COUNT(*) vs SUM(column) — inflated percentages over 100%

**Pattern:** Computing a ratio or percentage where the denominator uses `COUNT(*)` (counts rows) instead of `SUM(column)` (sums values). Each row represents a batch with N items, but COUNT returns 1 per row. Result: percentage = `sum(batches) / count(rows)` = wildly inflated (800%, 1193%, 2000%).

**Example:** Quiz app — each quiz attempt has `totalQuestions=10` and `correctAnswers=8`. Computing "accuracy" as `SUM(correctAnswers) / COUNT(*)` gives `8/1 = 800%` for one quiz, `40/5 = 800%` for five quizzes.

```typescript
// BUG: counts quiz attempt ROWS, not questions answered
answeredQuestions: sql<number>`cast(count(*) as integer)`,
correctAnswers: sql<number>`cast(coalesce(sum(${quizAttempts.correctAnswers}), 0) as integer)`,
// ...
accuracy: answered > 0 ? Math.round((correct / answered) * 100) : 0,  // → 800%

// FIX: sum the actual question counts
answeredQuestions: sql<number>`cast(coalesce(sum(${quizAttempts.totalQuestions}), 0) as integer)`,
```

**Why it's deadly:**
- No error thrown — the SQL is valid, just semantically wrong
- Values look "plausible" at first glance (large percentages seem like a display issue)
- Frontend may clamp the visual (SVG circle maxes at 100%) but raw text shows the real number
- Works "correctly" if each row has exactly 1 item (masking the bug in simple tests)

**Detection:** If any percentage-based UI shows values > 100%, check whether the denominator is `COUNT(*)` when it should be `SUM(actual_quantity_column)`. The mismatch is always: counting TRANSACTIONS instead of UNITS.

**Rule of thumb:** When computing `total / answered`, ask: "Is the denominator counting rows or counting what the user actually answered?" If each row represents a batch/group, use SUM, not COUNT.

## Overlap Notes

- `career-ops` skill (productivity category) has project-specific AI debugging patterns in `references/nextjs-server-action-debugging.md` (parseAIResponse, anti-hallucination, outreach null safety, Content-Disposition for file serving). The pitfall above generalizes the LLM JSON parsing issue; the career-ops skill has the exact code, call sites, and project architecture.
