# SPEC template

Copy to your private project planning area before implementation.

```markdown
# SPEC: <feature name>

Status: draft | frozen

## Context
Why this exists. Who benefits.

## Baseline
Evidence of what exists today: files, endpoints, tests and known constraints.

## Functional requirements
### RF-01: <name>
User story: As <actor>, I want <action>, so that <value>.

Acceptance criteria (EARS):
- WHEN <condition> THE SYSTEM SHALL <behavior>.
- IF <condition> THEN THE SYSTEM SHALL <behavior>.

## Non-functional requirements
- Security and validation:
- Performance target:
- Contract parity: desktop | web | mobile

## Blocked decisions
| ID | Decision | Impact | Owner |
|---|---|---|---|
| BD-01 | | | |

## Out of scope
- <item>

## Dependencies
- <item>
```

A frozen SPEC is the implementation contract. Change it through a new reviewed version, not silent code drift.
