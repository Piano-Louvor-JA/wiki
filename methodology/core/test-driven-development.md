# Test-Driven Development

> **Metodologia pública** — RED-GREEN-REFACTOR, testes antes do código, coverage 100% + mutation. Aplica-se a qualquer stack.

---
## Regressão-First (Regression Guard, 27/09)

Antes do primeiro RED de uma mudança em código existente:
1. **Teste do comportamento ATUAL** que não pode quebrar → deve estar VERDE antes de mudar qualquer linha (prova a rede existe).
2. Só então o ciclo RED-GREEN-REFACTOR do comportamento NOVO.
3. Bug encontrado no caminho = teste de regressão ANTES do fix (nunca fix sem teste que o reproduza).

Sem o passo 1, o GREEN do novo código pode estar pisando num consumidor quebrado — e você só descobre no prod. Matriz de impacto e regras completas: `software-development/regression-guard`.

## Jev como gate barato dentro do ciclo (System One, $0)

Decisões binárias NÃO gastam LLM grande — rodar via `~/.hermes/scripts/jev_ask.py`:
- **Antes de escrever o teste**: `--preset task_triage` confirma o tipo da mudança (bug/feature/refactor/spike) — tipo errado = spec errada.
- **Antes de commitar**: `--preset confidence` no resumo da solução — noul 0.35-0.65 = evidência fraca, escrever mais um teste antes de commitar.
- Free tier com 422 transitório: 2 falhas seguidas = seguir sem o gate (nunca bloquear por indisponibilidade do Jev).

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## FAIL → GREEN → REFACTOR Cycle (Project Reference)

Core TDD cycle used in real projects: agenda-iasd-jau (FASE 4: 189 tests/100%, FASE 8: 305 tests), TestForge hexagonal migration (260→509 tests). Pattern: write ONE failing test → minimum code to pass → refactor both test and production code. Coverage must hit 100% before next feature.

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask the user first):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

## Red-Green-Refactor Cycle

### RED — Write Failing Test

Write one minimal test showing what should happen.

**Good test:**
```python
def test_retries_failed_operations_3_times():
    attempts = 0
    def operation():
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            raise Exception('fail')
        return 'success'

    result = retry_operation(operation)

    assert result == 'success'
    assert attempts == 3
```
Clear name, tests real behavior, one thing.

**Bad test:**
```python
def test_retry_works():
    mock = MagicMock()
    mock.side_effect = [Exception(), Exception(), 'success']
    result = retry_operation(mock)
    assert result == 'success'  # What about retry count? Timing?
```
Vague name, tests mock not real code.

**Requirements:**
- One behavior per test
- Clear descriptive name ("and" in name? Split it)
- Real code, not mocks (unless truly unavoidable)
- Name describes behavior, not implementation

### Verify RED — Watch It Fail

**MANDATORY. Never skip.**

```bash
# Use terminal tool to run the specific test
pytest tests/test_feature.py::test_specific_behavior -v
```

Confirm:
- Test fails (not errors from typos)
- Failure message is expected
- Fails because the feature is missing

**Test passes immediately?** You're testing existing behavior. Fix the test.

**Test errors?** Fix the error, re-run until it fails correctly.

### GREEN — Minimal Code

Write the simplest code to pass the test. Nothing more.

**Good:**
```python
def add(a, b):
    return a + b  # Nothing extra
```

**Bad:**
```python
def add(a, b):
    result = a + b
    logging.info(f"Adding {a} + {b} = {result}")  # Extra!
    return result
```

Don't add features, refactor other code, or "improve" beyond the test.

**Cheating is OK in GREEN:**
- Hardcode return values
- Copy-paste
- Duplicate code
- Skip edge cases

We'll fix it in REFACTOR.

### Verify GREEN — Watch It Pass

**MANDATORY.**

```bash
# Run the specific test
pytest tests/test_feature.py::test_specific_behavior -v

# Then run ALL tests to check for regressions
pytest tests/ -q
```

Confirm:
- Test passes
- Other tests still pass
- Output pristine (no errors, warnings)

**Test fails?** Fix the code, not the test.

**Other tests fail?** Fix regressions now.

### REFACTOR — Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers
- Simplify expressions

Keep tests green throughout. Don't add behavior.

**If tests fail during refactor:** Undo immediately. Take smaller steps.

### Repeat

Next failing test for next behavior. One cycle at a time.

## Why Order Matters

**"I'll write tests after to verify it works"**

Tests written after code pass immediately. Passing immediately proves nothing:
- Might test the wrong thing
- Might test implementation, not behavior
- Might miss edge cases you forgot
- You never saw it catch the bug

## Browser API Mocking — stubGlobal vs spyOn Pattern

When mocking browser APIs not implemented in jsdom (e.g., `navigator.clipboard`), use `vi.stubGlobal` instead of `vi.spyOn`.

**❌ WRONG — vi.spyOn fails:**

```tsx
// Error: "object to spy upon not found"
vi.spyOn(navigator, 'clipboard').mockReturnValue({ writeText: vi.fn() });
```

jsdom doesn't implement all browser APIs. `navigator.clipboard` doesn't exist, so `vi.spyOn` throws.

**✅ CORRECT — vi.stubGlobal works:**

```tsx
describe('ComponentWithClipboard', () => {
  const mockClipboard = {
    writeText: vi.fn<() => Promise<void>>().mockResolvedValue(),
  }

  beforeEach(() => {
    vi.stubGlobal('navigator', { clipboard: mockClipboard })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('copies text to clipboard', async () => {
    const user = userEvent.setup({ delay: null })
    render(<ComponentWithClipboard text="test" />)

    const copyButton = screen.getByRole('button', { name: /copy/i })
    await user.click(copyButton)

    expect(mockClipboard.writeText).toHaveBeenCalledWith('test')
  })
})
```

**Key points:**
- `vi.stubGlobal('navigator', { clipboard: mockClipboard })` — adds the entire object globally
- `vi.unstubAllGlobals()` in `afterEach` — cleanup after each test
- Reference the mock directly in assertions (`mockClipboard.writeText`), not `navigator.clipboard`
- Use TypeScript generics `vi.fn<() => Promise<void>>()` for typed mocks
- `userEvent.setup({ delay: null })` — synchronous interactions (no real delay)

**Common browser APIs that need stubGlobal:**
- `navigator.clipboard` — clipboard operations
- `navigator.share` — native share dialog
- `navigator.mediaDevices` — camera/microphone access
- `window.speechSynthesis` — text-to-speech

**When to use vi.spyOn instead:**
- Browser APIs that ARE in jsdom (`window.location`, `document.querySelector`, etc.)
- Properties that exist but need behavior override
- Spying on existing methods without replacing the entire object

Test-first forces you to see the test fail, proving it actually tests something.

**"I already manually tested all the edge cases"**

Manual testing is ad-hoc. You think you tested everything but:
- No record of what you tested
- Can't re-run when code changes
- Easy to forget cases under pressure
- "It worked when I tried it" ≠ comprehensive

Automated tests are systematic. They run the same way every time.

**"Deleting X hours of work is wasteful"**

Sunk cost fallacy. The time is already gone. Your choice now:
- Delete and rewrite with TDD (high confidence)
- Keep it and add tests after (low confidence, likely bugs)

The "waste" is keeping code you can't trust.

**"TDD is dogmatic, being pragmatic means adapting"**

TDD IS pragmatic:
- Finds bugs before commit (faster than debugging after)
- Prevents regressions (tests catch breaks immediately)
- Documents behavior (tests show how to use code)
- Enables refactoring (change freely, tests catch breaks)

"Pragmatic" shortcuts = debugging in production = slower.

**"Tests after achieve the same goals — it's spirit not ritual"**

No. Tests-after answer "What does this do?" Tests-first answer "What should this do?"

Tests-after are biased by your implementation. You test what you built, not what's required. Tests-first force edge case discovery before implementing.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to the test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for the code you touch. |

## Red Flags — STOP and Start Over

If you catch yourself doing any of these, delete the code and restart with TDD:

- Code before test
- Test after implementation
- Test passes immediately on first run
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**ALL of these mean: Delete code. Start over with TDD.**

### Committing Before GREEN — False TDD Claims

**Problema**: FASE 2 foi commitada com mensagem "TDD 100% coverage" mas testes estavam falhando (23 pass, 15 fail, 3 errors).

**Solução**: NUNCA commitar até GREEN estar completo. Verifique antes:

```bash
# Rodar todos os testes
bun test --run

# Verificar: deve mostrar "X pass, 0 fail"
# Se há falhas → corrigir → re-rodar → só então commitar
```

**Pitfall**: Commit message diz "TDD 100% coverage" mas tests falham = inconsistência entre CLAIM e REALITY.

**Best practice**: Pre-commit hook impede push se coverage < 100% (ver `jwt-rs256-auth-patterns` → Pre-commit Hook).

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for API. Write the assertion first. Ask the user. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify the design. |


## Vitest + React Testing Library Pitfalls

Learned from real-world Next.js component testing (Vitest v3, jsdom, RTL). These apply when writing tests for React components that use async state, timers, or multiple fetch calls.

### fakeTimers + userEvent = Timeout
**NEVER combine `vi.useFakeTimers()` with `@testing-library/user-event`** — causes infinite timeouts. If a component uses `setTimeout` internally, use `fireEvent` (synchronous) instead of `userEvent`, or use `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })`.

### fakeTimers + waitFor = INCOMPATIBLE
`waitFor` uses `setTimeout(50)` for internal polling — this **FREEZES** under fakeTimers. The test hangs forever.
**Solution:** Use `vi.useFakeTimers({shouldAdvanceTime:true})` + `act(() => vi.advanceTimersByTime(N))` + **direct assertions** (no `waitFor`). The `act()` wrapper is **mandatory** when `advanceTimersByTime` triggers React state updates — without it, the component won't re-render and assertions fail.
```js
import { act } from '@testing-library/react';

vi.useFakeTimers({ shouldAdvanceTime: true });
render(<Component />);
fireEvent.click(button);
act(() => vi.advanceTimersByTime(2500));  // MUST wrap in act() for React state updates
expect(screen.getByText(/Expected Text/)).toBeInTheDocument();
vi.useRealTimers();
```

### vi.doMock does NOT intercept static imports
If the component uses `import { hook } from '../path'` at the top, `vi.doMock('../path', ...)` inside a test body will NOT intercept it — the original was already loaded.
**Solution:** Use `vi.mock` at the TOP LEVEL (hoisted by Vitest) with a mutable `vi.fn()`:
```js
const mockFn = vi.fn(() => defaultValue);
vi.mock('../hooks/use-thing', () => ({
  useThing: () => ({ value: mockFn }),
}));
// Then per-test: mockFn.mockReturnValue(specificValue);
```

### Unicode in jsdom DOM
Accented characters (ç, ã, é) may render as `\u00E7\u00E3` in jsdom. Use regex instead of exact strings:
```js
// BAD: screen.getByText('Pontuação deste capítulo')
// GOOD:
screen.getByText(/Pontua..o deste cap.tulo/);
```

### "Found multiple elements" with global mock returns
When mocking a hook to return identical values for all items (e.g., mastery=1.0 for all modules), `getByLabelText` fails because N elements match. Use `getAllByLabelText` and assert `.length`.

### globals: true in vitest.config.js
When `globals: true` is set, `describe`, `it`, `expect`, `vi` are global — no need to import them. Only import RTL utilities (`render`, `screen`, `fireEvent`, `waitFor`, `act`).

### window.open Spy Blocks in jsdom
`vi.spyOn(window, 'open').mockReturnValue(null)` can hang. Use `vi.stubGlobal('open', vi.fn())` instead.

### Mocking Browser APIs Not in jsdom (e.g., navigator.clipboard)
jsdom doesn't implement all browser APIs (like `navigator.clipboard`). `vi.spyOn` on non-existent properties fails with "object to spy upon not found". Use `vi.stubGlobal` with a custom mock object and clean up in `afterEach`:
```js
describe('Component', () => {
  const mockClipboard = {
    writeText: vi.fn<() => Promise<void>>().mockResolvedValue(),
  }

  beforeEach(() => {
    vi.stubGlobal('navigator', { clipboard: mockClipboard })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('copies to clipboard', () => {
    render(<Component />)
    // Use mockClipboard.writeText in assertions, not navigator.clipboard
    expect(mockClipboard.writeText).toHaveBeenCalledWith('text')
  })
})
```
**Key:** Define the mock object at describe level, stub in beforeEach, unstub in afterEach. Access the mock directly (e.g., `mockClipboard.writeText`) — don't use `navigator.clipboard` in tests.

### Mock Fetch Ordering for Multi-Fetch Components
Components that call `fetch()` multiple times on mount need careful mock ordering:
```js
mockFetch
  .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve(dataApi) })
  .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve(progressApi) })
  .mockResolvedValue({ ok: true, json: () => Promise.resolve(defaultResponse) }); // catch-all
```
Use `mockResolvedValue` (no "Once") for the last handler to absorb unexpected intermediate fetch calls.

### Shuffled Content = Flaky findByText
Components that `shuffleArray()` before rendering make exact text match flaky. Use regex patterns:
```js
// BAD: await screen.findByText('Quem construiu a arca?')
// GOOD:
await screen.findByText(/construiu a arca|primeiro livro|Bíblia/, {}, { timeout: 5000 });
```

### Full Quiz Flow Tests Are Fragile
Testing complete game loops with multiple auto-advance `setTimeout`s is fragile. Test individual states and transitions instead.

### waitFor Assertion Pattern for Async Side-Effects
When testing async side-effects (e.g., `window.open` after fetch):
```js
await waitFor(() => { expect(mockFn).toHaveBeenCalled(); });
expect(mockFn).toHaveBeenCalledWith(expected, args); // separate line
```
Put the "was called" check inside `waitFor`, then assert specific args outside.

### fakeTimers Leakage Between Test Files
When another test file (e.g., BibleYearRich.test.tsx) uses `vi.useFakeTimers()` and doesn't properly clean up, subsequent test files that use `vi.useFakeTimers({ shouldAdvanceTime: true })` + `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })` become flaky — `waitFor` polls sometimes pass, sometimes don't, depending on which file ran first.
**Root cause:** Vitest runs files in parallel by default; fake timer state can leak across files if cleanup is incomplete.
**Solution:** ALWAYS reset timers at the start of your test file's `beforeEach`:
```js
beforeEach(() => {
  vi.useRealTimers(); // Reset leaked fake timers from other files
  vi.useFakeTimers({ shouldAdvanceTime: true });
  vi.setSystemTime(new Date(2026, 5, 7, 10, 0, 0)); // Fixed date for determinism
  // Also clear leaked global.fetch mocks from other files
  global.fetch = undefined;
  // ... rest of setup
});
```
**Key:** `vi.useRealTimers()` MUST come BEFORE `vi.useFakeTimers()` — calling useFakeTimers twice without useRealTimers in between is a no-op.

### global.fetch Mock Leakage Between Test Files
When test files mock `global.fetch` with `vi.fn()` and don't restore it in `afterEach`, subsequent test files that set `global.fetch` in individual tests may still hit the leaked mock for URLs not explicitly handled.
**Solution:** Clear `global.fetch = undefined` in `beforeEach` of any file that uses per-test fetch mocks.

### data-testid Composition Bug
When a component uses `data-testid={`day-${d.id}`}` and `d.id` contains a prefix like `'day-1'`, the resulting testid becomes `day-day-1` — a silent, hard-to-debug mismatch.
**Rule:** Mock data IDs must match the format the component expects in testids. If the component prepends `day-`, mock IDs should be plain numbers (`'1'`, `'2'`). If the component doesn't prepend, IDs can include the prefix. Always trace the testid template before choosing mock IDs.

### highlightVerses-Style Regex Mocks
When a component uses regex like `>([^<]+)<` to find and highlight text (e.g., Bible verse references), the mock HTML content MUST have the target text INSIDE HTML tags (e.g., `<p>João 3:16 is here</p>`), NOT outside (e.g., `</p> João 3:16`). Text outside tags is invisible to the regex and won't be highlighted, causing tests to fail with "not found" errors.
**Pattern:** Always wrap mock content in proper HTML tags when testing highlight/wrapper components.

### Coverage Runs Are Slow
Full coverage with many component tests can take 300s+. Use `background=true` with `notify_on_complete=true` or pipe to file:
```bash
npx vitest run --exclude='tests/integration/**' --coverage 2>&1 | tee /tmp/cov.txt
```

### Batch patching test files — verify each patch
When using `execute_code` + `hermes_tools.patch()` to batch-add tests to multiple files, the tool can return empty output without signaling failure. Always verify with `git diff --stat` and run each modified test file individually before trusting the batch.

### Patch must reference exact variable names in test scope
When adding tests to an existing test file, READ the file first to find the correct mock variable names. Using wrong names (e.g., `mockBadges` when the file defines `mockRequirements`) causes `ReferenceError` that only surfaces at test runtime — not at patch time.

### Mobile-specific component rendering
Components with conditional mobile/desktop rendering (bottom sheet vs tooltip, responsive hooks) may not render the mobile variant in a basic `render()` call. Check if the component reads from a media query hook, viewport size, or prop. The test must set up the correct context (mock the hook or set the prop) before querying mobile-specific elements.

### delegate_task Subagents Timeout Writing Tests
Do NOT use `delegate_task` to create test files — subagents consistently timeout. Write test files directly with `write_file` / `patch` tools instead.

### vi.hoisted for dynamic mock values per-test
When a mocked hook needs different return values per-test but `vi.mock` is hoisted (can't access test-local variables), use `vi.hoisted()` to create a mutable state object:
```js
const { xpGained, setXpGained } = vi.hoisted(() => {
  const state = { xpGained: 0 };
  return { ...state, setXpGained: (v) => { state.xpGained = v; } };
});
vi.mock('../hooks/use-xp', () => ({
  useXP: () => ({ xpGained, addXP: vi.fn() }),
}));
// In individual test:
setXpGained(50);
```
This avoids the `vi.doMock` static-import problem without needing hardcoded return values.

### v8 IIFE arrow functions inflate funcs coverage
Arrow functions used as IIFEs in JSX (e.g., `{(() => getLabel(score))()}`) are counted as separate functions by v8 coverage. This artificially lowers `funcs %` even when the code IS executed. No fix — either accept the gap or refactor to a named helper.

### dead code removal > testing dead code
Before writing tests for uncovered branches, verify the code is reachable. Unused private functions, unreachable else branches (guarded by earlier returns), and impossible state combinations are dead code. Remove them instead of testing — it improves coverage % AND reduces maintenance burden.

### TypeScript ref types for useRef with timers
When using `useRef` with timer IDs in React components, `NodeJS.Timeout` causes TypeScript errors in browser-only environments because it's Node.js-specific. Use `ReturnType<typeof setTimeout>` instead — this works in both Node.js and browser contexts.

**❌ WRONG — NodeJS.Timeout fails in browser:**
```tsx
const timerRef = useRef<NodeJS.Timeout>()  // Error: Expected 1 arguments, but got 0
```

**✅ CORRECT — ReturnType<typeof setTimeout> works everywhere:**
```tsx
const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

// Set timer
timerRef.current = setTimeout(() => setCopied(false), 2000)

// Cleanup in useEffect
useEffect(() => {
  return () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current)
    }
  }
}, [])

// Clear timer before setting new one
if (timerRef.current) {
  clearTimeout(timerRef.current)
}
timerRef.current = setTimeout(...)
```

**Why:** `NodeJS.Timeout` is defined in Node.js type definitions but doesn't exist in browser type contexts. `ReturnType<typeof setTimeout>` resolves to `number` in browser and `NodeJS.Timeout` in Node.js automatically.

**Pattern:** Always use `ReturnType<typeof setTimeout>` for any `setTimeout`/`setInterval` refs in React components, even if you think you're only in browser context — it prevents migration pain and keeps code cross-platform compatible.

### Shared mock data mutation breaks other tests
Adding items to a shared `mockQuizData` or similar test fixture object (e.g., adding a 3rd card) affects ALL tests that reference it. Tests asserting on specific card counts or button indices will break silently.
**Best practice:** Create local mocks for tests needing different data shapes: `const localMock = { ...sharedMock, cards: [...customCards] }`.

### Quiz/game requeue pattern blocks intermediate score testing
Components that requeue wrong answers (`newCards.push(currentCard)`) make it impossible to finish with intermediate accuracy using small mock datasets — wrong cards keep returning until answered correctly. To test score-dependent feedback, either: (a) use a mock with 5+ cards and strategically answer some wrong then right, (b) mock the requeue logic, or (c) accept the coverage gap.

### Deterministic quiz order via vi.mock('./types')
When a component imports `shuffleArray`, `shuffleOptions`, or `prioritizeUnseen` from a types/util module, random order makes tests non-deterministic. Mock the ENTIRE types module to make order predictable:
```js
vi.mock('./types', async () => {
  const actual = await vi.importActual('./types');
  return {
    ...actual,
    shuffleArray: vi.fn((arr) => [...arr]),           // identity — preserves order
    shuffleOptions: vi.fn((arr) => [...arr]),          // identity
    prioritizeUnseen: vi.fn((cards) => [...cards]),    // identity
  };
});
```
**Critical:** Use `vi.mock` (hoisted), NOT `vi.doMock` — the component's static imports are already resolved before `doMock` runs.

### Named unique options prevent "Found multiple elements" in quiz tests
When mocking quiz data with multiple cards, never reuse option text across cards (e.g., `['Right', 'Wrong1', 'Wrong2']` for every card). After clicking CHECK + CONTINUAR, DOM transitions can leave stale elements, causing `getByText('Wrong1')` to match multiple nodes.
**Pattern:** Use per-card prefixed names: `Q1Ok`, `Q1W1`, `Q1W2`, `Q2Ok`, `Q2W1`, etc.
```js
const cards = [
  { id: 'q1', pergunta: 'Q1?', resposta: 0, opcoes: ['Q1Ok', 'Q1W1', 'Q1W2', 'Q1W3'] },
  { id: 'q2', pergunta: 'Q2?', resposta: 1, opcoes: ['Q2W1', 'Q2Ok', 'Q2W2', 'Q2W3'] },
  // ...
];
```
This ensures `screen.getByText('Q1W1')` always matches exactly one element.

### Testing quiz completion when lives system ends the game
When a quiz has `MAX_LIVES=3` and decrements on wrong answers, the quiz ends in `handleNext` (after CONTINUAR click) when `lives <= 0`. The test must:
1. Answer wrong → click CHECK → click CONTINUAR (lives goes from 3→2, shows next card)
2. Answer wrong → click CHECK → click CONTINUAR (lives goes from 2→1)
3. Answer wrong → click CHECK → click CONTINUAR (lives goes from 1→0 → quiz ends → result screen)

Do NOT skip the final CONTINUAR click — the game doesn't auto-end on the wrong answer itself, only when the player advances with lives=0.

## Contributing to Hermes Agent Core (Python)

When writing tests for the Hermes Agent repo (`~/.hermes/hermes-agent`), follow these project-specific patterns.

## 100% Coverage Patterns for Authentication Module

When achieving 100% coverage (statements, branches, functions, lines) for authentication modules with JWT RS256 and bcrypt, use these patterns:

### Coverage-Gaps Files: Separate Artifact Tests from Business Logic

Create dedicated `*.coverage-gaps.test.ts` files to hit difficult branches while keeping main test files focused on business logic:

```ts
// auth.service.coverage-gaps.test.ts
describe('auth.service > stub default coverage (L145-147)', () => {
  it('deve cobrir findRefreshTokenByJti, revokeRefreshTokens e revokeAllUserTokens do stub default', () => {
    // Covers artifact-level paths that business tests don't trigger
  });
});
```

**Why:** Main tests cover happy paths; gap tests cover:
- Stub default methods that only run when real repo is missing
- Nullish coalescing `??` branches
- Error paths that require controlled failure injection

### Nullish Coalescing (`??`) Branch Coverage

`??` ONLY triggers on `null` or `undefined`, NOT on empty strings or falsy values:

```ts
// src/auth/auth.service.ts L62
const congregacao_id = payload.congregacao_id ?? '';

// ❌ EMPTY STRING DOES NOT TRIGGER ?? — use null instead
payload.congregacao_id = ''; // ?? ignored

// ✅ USE NULL TO TRIGGER ??
payload.congregacao_id = null; // ?? executes
```

**Pattern:** Generate JWT tokens directly with `null` payload to hit `??` branches:

```ts
import { generateRefreshToken } from '@/auth/jwt.service';

const refreshToken = generateRefreshToken({
  sub: 'user-null-cong',
  email: 'nullcong@test.com',
  role: 'MEMBER',
  congregacao_id: null, // null to trigger ?? '' in refresh method
});
```

### Generate JWT Directly for Controlled Payload Testing

When testing authentication flow with specific payload states, use `generateAccessToken`/`generateRefreshToken` directly instead of going through login (which constructs MemberRecord with typed fields that can't be null):

```ts
import { generateRefreshToken } from '@/auth/jwt.service';

const refreshToken = generateRefreshToken({
  sub: 'user-1',
  email: 'test@test.com',
  role: 'MEMBER',
  congregacao_id: null, // control payload state directly
});

// Then test refresh() with this token
const result = await refresh(refreshToken);
expect(result.accessToken).toBeTruthy();
```

**Pitfall:** Using `login()` then expecting `congregacao_id` to be `null` in JWT payload — `MemberRecord` type enforces `congregacao_id: string`, so login never produces `null`. Direct token generation bypasses type constraints for testing rare paths.

### Repository Singleton Test Injection

For services with singleton repositories (default stub + optional injection pattern), use `_setTestRepository()` to inject mocks that override default stub methods:

```ts
import { _setTestRepository, _resetDefaultAuthService } from '@/auth/auth.service';

describe('auth.service > _setTestRepository', () => {
  afterEach(() => {
    _resetDefaultAuthService(); // cleanup between tests
  });

  it('deve injetar repo customizado no singleton', async () => {
    const mockRepo: AuthRepository = {
      findMemberByEmail: vi.fn().mockResolvedValue(mockMember),
      revokeAllUserTokens: vi.fn().mockResolvedValue(undefined),
      // ... override specific methods
    };

    _setTestRepository(mockRepo);

    const { refreshToken } = await login('test@test.com', 'senha123');
    expect(mockRepo.revokeAllUserTokens).toHaveBeenCalled();
  });
});
```

**Pattern:** Override ONLY the methods your test calls. Let singleton default stub handle others. Reset singleton after each test to prevent leakage.

### Middleware Role Hierarchy Default Case

When testing role hierarchy switch statements with default case (error path for unknown roles), pass a role that doesn't exist in the hierarchy:

```ts
describe('auth.middleware > getRoleHierarchy default case (L63)', () => {
  it('deve retornar 403 para role desconhecido no switch default', async () => {
    const token = generateAccessToken({
      sub: 'user-1',
      email: 'test@test.com',
      role: 'UNKNOWN_ROLE', // triggers switch default
      congregacao_id: '1',
    });

    const response = await app.request('/protected', {
      headers: { authorization: `Bearer ${token}` }
    });

    expect(response.status).toBe(403);
  });
});
```

### JWT Service Coverage Gaps: Missing Environment Variables

Lines that throw when JWT keys aren't configured (L20, L29 in jwt.service.ts) need test isolation that temporarily deletes env vars:

```ts
describe('jwt.service > getPrivateKey sem env var (L20)', () => {
  const originalKey = process.env.JWT_PRIVATE_KEY_PATH;

  afterEach(() => {
    process.env.JWT_PRIVATE_KEY_PATH = originalKey; // restore
  });

  it('deve lançar erro se JWT_PRIVATE_KEY_PATH não estiver configurado', () => {
    delete process.env.JWT_PRIVATE_KEY_PATH; // trigger error path

    expect(() => generateAccessToken({ sub: 'u', email: 'e', role: 'M', congregacao_id: '1' }))
      .toThrow('JWT_PRIVATE_KEY_PATH não está configurado');
  });
});
```

### GPG Signing Pitfall in Automated Contexts

When committing from a non-interactive session (no tty for GPG passphrase), `git commit` fails with `error: Couldn't get agent socket?`. Disable signing per-commit:

```bash
git -c commit.gpgsign=false commit -m "feat: description"
```

**Do NOT modify global git config to disable signing** — only override per command. Global changes affect interactive sessions where GPG signing IS desired.

### Vitest Coverage Provider: Use v8 (not c8)

For Node.js projects with Vitest, use v8 provider (native to V8) for accurate line-by-line coverage:

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    coverage: {
      provider: 'v8', // not 'c8'
      all: true,
      include: ['src/**/*.ts'],
      exclude: ['**/types/**', '**/index.ts'],
      lines: 100,
      functions: 100,
      branches: 100,
      statements: 100,
    },
  },
});
```

**Pre-commit hook pattern:** Enforce 100% coverage in pre-commit to catch regressions before commit:

```bash
#!/bin/bash
# .git/hooks/pre-commit
bun run lint && bun run typecheck && bun run test:coverage
COVERAGE=$(bun run test:coverage 2>&1 | grep "All files" | awk '{print $2}' | tr -d '%')
if [ "$COVERAGE" != "100" ]; then
  echo "Coverage $COVERAGE% < 100% — commit blocked"
  exit 1
fi
```

### Dev Environment Setup

```bash
cd ~/.hermes/hermes-agent
uv venv .venv --python python3
uv pip install -e ".[dev]" --python .venv/bin/python
```

**Pitfall:** `python` command not found on the Oracle Cloud VM. Use `python3` (system 3.12) or `.venv/bin/python` (venv 3.11).

### Running Tests

```bash
# Single test file
.venv/bin/python -m pytest tests/tools/test_delegate_task_model_override.py -v

# All tests in a directory
.venv/bin/python -m pytest tests/tools/ -v

# With xdist (4 workers, same as CI)
.venv/bin/python -m pytest tests/ -n 4 -q
```

CI uses `scripts/run_tests.sh` (uv venv + 4 xdist workers).

### Test Fixture Pattern: `_create_delegate_tool()`

The repo uses a helper factory `_create_delegate_tool()` that constructs a `DelegateTool` with sensible mock defaults. Study `tests/tools/test_delegate.py` for the exact fixture before writing new tests.

```python
# Typical test setup
def _create_delegate_tool(**overrides):
    """Create a DelegateTool with mock agent and config."""
    agent = MagicMock()
    agent.model = "test-model"
    # ... defaults from test_delegate.py
    return DelegateTool(agent=agent, config=overrides)

class TestMyFeature(unittest.TestCase):
    def setUp(self):
        self.tool = _create_delegate_tool()
```

### Mocking AIAgent Construction

When testing delegate_tool behavior that spawns child agents, mock the `AIAgent` constructor:

```python
from unittest.mock import patch, MagicMock, AsyncMock

@patch("tools.delegate_tool.AIAgent")
def test_child_uses_task_model(self, mock_ai_agent_cls):
    mock_child = MagicMock()
    mock_child.run = AsyncMock(return_value="done")
    mock_ai_agent_cls.return_value = mock_child

    result = self.tool.delegate_task(tasks=[{
        "title": "Test",
        "description": "desc",
        "prompt": "do it",
        "model": "specific-model"  # per-task override
    }])

    # Verify AIAgent was constructed with the task-specific model
    call_kwargs = mock_ai_agent_cls.call_args[1]
    assert call_kwargs["model"] == "specific-model"
```

### Backward Compatibility Tests

When adding new optional fields to existing schemas, always include tests that omit the new fields to verify zero regression:

```python
def test_backward_compat_no_model_field(self):
    """Tasks without model/provider field use delegation defaults."""
    result = self.tool.delegate_task(tasks=[{
        "title": "Test",
        "description": "desc",
        "prompt": "do it"
        # no "model" or "provider" keys
    }])
    assert result  # succeeds with default behavior
```

### GPG Signing in Automated Contexts

When committing from a non-interactive session (no tty for GPG passphrase), disable signing per-commit:

```bash
git -c commit.gpgsign=false commit -m "feat: description"
```

Do NOT modify global git config to disable signing — only override per command.

### Key Source Locations in delegate_tool.py

| Line Range | Function/Section |
|------------|-----------------|
| ~870-1100 | `_build_child_agent()` |
| ~1934 | `delegate_task()` entry point |
| ~2040-2072 | Task dispatch loop |
| ~2369-2489 | `_resolve_delegation_credentials()` |
| ~2700-2830 | Schema definition |

These shift as the file evolves — always verify with `grep -n` before patching.

## Dogfood / Self-Referential Testing (Tool Testing Itself)

When writing tests where a tool tests its own codebase (e.g., a test generator testing itself, an analyzer analyzing its own source):

### Strategy: Split by External Dependencies

1. **Identify no-dep components** — modules that work without external services (analyzers, reporters, formatters, type checkers). Test these directly with real code, reading real source files from the repo:
   ```ts
   import { CodeAnalyzer } from '../../src/lib/analyzer/index.js';
   import { readFile } from 'node:fs/promises';
   import { resolve } from 'node:path';

   it('analyzes its own source', async () => {
     const analyzer = new CodeAnalyzer();
     const filePath = resolve(__dirname, '../../src/lib/analyzer/index.ts');
     const source = await readFile(filePath, 'utf-8');
     const analysis = await analyzer.analyze(filePath, source);
     expect(analysis.language).toBe('typescript');
   });
   ```

2. **Mock external services at module boundary** — when a component calls LLM/HTTP internally (e.g., pipeline calls LLM router), either:
   - Skip those paths in dogfood tests (focus on no-dep paths only), OR
   - Mock the external module with `vi.mock` at top level

3. **Module importability smoke test** — verify all core exports resolve:
   ```ts
   it('all core modules importable', async () => {
     const { Pipeline } = await import('../../src/lib/pipeline/index.js');
     expect(Pipeline).toBeDefined();
   });
   ```

### Pitfall: Structural Assumptions About Analyzer Output

Class-based source code (e.g., `class Foo { bar() {} }`) produces entries in `analysis.classes`, NOT in `analysis.functions`. Always verify the actual output shape before writing assertions:
```ts
// WRONG — returns 0 for class-based code:
expect(analysis.functions.length).toBeGreaterThan(0);
// CORRECT — methods live under .classes:
expect(analysis.classes.length).toBeGreaterThan(0);
```
Run the analyzer on one real file first, inspect the output, then write assertions that match reality.

### Pitfall: Generated Output Directories

Tests that exercise report generators or file-writing components create output directories (e.g., `./myapp-report/`). Add these to `.gitignore` immediately to avoid accidentally committing test artifacts.

### npm Script Convention

Add a dedicated script for running dogfood tests in isolation:
```json
"dogfood": "vitest run tests/dogfood/"
```

## Testing Anti-Patterns

- **Testing mock behavior instead of real behavior** — mocks should verify interactions, not replace the system under test
- **Testing implementation details** — test behavior/results, not internal method calls
- **Happy path only** — always test edge cases, errors, and boundaries
- **Brittle tests** — tests should verify behavior, not structure; refactoring shouldn't break them

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without the user's explicit permission.
