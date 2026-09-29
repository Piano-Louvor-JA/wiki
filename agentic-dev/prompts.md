# Working patterns for coding agents

## Start with context

Before changing code:

1. Read the target repository's `AGENTS.md`, README and contribution guide.
2. Inspect the baseline implementation, scripts and relevant tests.
3. Read the task, SPEC and PLAN when they exist.

## Baseline audit before a SPEC

Do not specify behavior that already exists. Inspect repository files, package scripts, tests and public contracts first. Documentation can be stale; executable evidence has priority.

## Parity by contract

When a desktop feature has web or mobile scope, preserve the same public API behavior. Do not translate UI components across stacks. Implement native clients against the same tested contract.

## Spec-driven development

For non-trivial changes use this sequence:

```text
SPECIFY → PLAN → IMPLEMENT → VERIFY
```

Use the public [SPEC](templates/spec-template.md), [PLAN](templates/plan-template.md) and [TASK](templates/task-template.md) templates.

## Evidence

A change is not complete without execution evidence:

- Behavior tests exercise the implementation.
- Relevant lint, type-check, tests and build pass.
- UI work receives an appropriate runtime validation.
- Shared-contract changes name affected consumers.

## Anti-patterns

| Anti-pattern | Correct approach |
|---|---|
| Assume deployment proves migration success | Verify health and intended schema after release |
| Runtime asset excluded from packaging | Keep required runtime assets inside packaging inputs |
| Test reimplements production logic | Import and exercise production code |
| Browser check presented as Electron validation | Validate the native Electron window |
| Undecided credential, store or API decision | Stop and request the decision |
| Direct feature PR to `main` | Open PR to `staging` |
