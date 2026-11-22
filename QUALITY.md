# Quality standards

How the PIANO / LouvorJA projects keep code trustworthy: test-driven
development, coverage gates, and review discipline. These are the ecosystem
defaults; a repository's own contribution guide overrides anything here.

## Test-driven development

Development follows the RED-GREEN-REFACTOR cycle from the first line:

1. **RED** — write the failing test for the behaviour that does not exist yet.
2. **GREEN** — write the minimum code that makes the test pass.
3. **REFACTOR** — clean up while keeping the tests green.

Code without a corresponding test is not a delivered feature; it is debt.

## Coverage thresholds

Automated test coverage gates are configured at **100% for statements,
branches, functions and lines**, with no per-file exceptions. A waiver is
reserved for genuinely unreachable code (for example, a platform guard) and
must be justified in a comment at the site.

Exceptions exist where mutation testing is used instead: some repositories run
a mutation-testing tool whose score is treated as the more honest metric,
because covered-but-unasserted code dies in mutation testing. Keep that gate
green where it is configured.

## What "done" means

A change is done when:

- lint, typecheck, tests and build pass locally, as documented in the
  repository;
- new behaviour has tests written in the same commit;
- documentation that describes public behaviour is updated in the same change;
- the pull request contains validation evidence and known limitations.

## Review discipline

- One focused outcome per pull request; split large changes.
- Reviewers may request changes; read what was asked, split the work if it is
  too large to review clearly, and push again.
- A human approves on top of any automated review. Automation never merges on
  its own.

## Working with coding agents

Development across the ecosystem is done with AI agents alongside humans.
Agents follow the same gates as anyone else:

- read the repository's agent guide before touching code;
- write real tests — a test that breaks the intended function and still passes
  is not a test;
- stop and ask when a decision depends on a human (accounts, credentials,
  store access) instead of inventing one;
- commit and push at the end of every cycle, on the branch the repository
  documents for that change.
