# PLAN template

Copy to the same private planning area as the approved SPEC.

```markdown
# PLAN: <feature>

Source: <SPEC reference>

## Phase 1 — <shippable outcome>

- [ ] F1-T1: <exact files, implementation step, verification command, commit message>
- [ ] F1-T2: <exact files, implementation step, verification command, commit message>

## Definition of Done
- [ ] <verifiable acceptance criterion>
```

Rules:

1. Each task names exact files and a verification command.
2. Keep tasks small enough for one atomic commit.
3. Each phase has a shippable outcome.
4. Mark work blocked by a decision as `BLOCKED BD-XX`; do not guess the decision.
