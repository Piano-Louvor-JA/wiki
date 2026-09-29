# Git and pull requests

## Branch flow

```text
feat/* or fix/*  →  pull request to staging  →  release pull request to main
```

Do not open feature PRs directly to `main`.

## Before opening a PR

1. Read the target repository instructions and relevant tests.
2. Inspect the baseline behavior and existing scripts.
3. Keep one focused outcome per PR.
4. Run the repository's relevant lint, type-check, tests and build.
5. Review the diff for unrelated formatting, generated files and sensitive data.
6. Describe validation evidence, limitations and affected consumers.

## Commits

Use small conventional commits, for example:

```text
feat(scope): add a focused capability
fix(scope): correct a regression
docs: clarify onboarding
```

## Review rules

- Review is required before merge under the organization process.
- Address feedback with evidence, not assumptions.
- Do not merge an incomplete or failing validation result.

## AI-agent rules

- Read `AGENTS.md` before changing code.
- Use a frozen SPEC and PLAN for non-trivial features.
- Stop for a human decision when credentials, store accounts, public API shape or architecture is undecided.
- Never discard unreviewed work blindly; inspect `git status` first.

See [agentic prompts](../agentic-dev/prompts.md).
