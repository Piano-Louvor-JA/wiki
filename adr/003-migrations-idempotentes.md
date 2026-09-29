# ADR-003: Idempotent migration execution

Status: Accepted

## Context

Database changes can be interrupted or retried. A migration runner must distinguish an already-applied safe operation from a real failure.

## Decision

Execute migrations as individually validated statements where supported by the database tooling. Recognize expected idempotent conditions, such as an existing column or table, while surfacing syntax and constraint failures.

## Consequences

- Re-running an already-applied safe migration is supported.
- Real migration failures remain visible and stop the release path.
- Post-release health and schema verification remain required.
