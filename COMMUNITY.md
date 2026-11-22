# Community platform

The public community features of PIANO / LouvorJA: how members join, how
content is shared and ranked, and how moderation works. This page describes
the public behaviour and contracts; operational configuration stays private.

## What the community covers

The ecosystem includes a community layer shared across the clients (web and
desktop) with feature parity:

- **Public collections** — members publish collections others can discover,
  use and save. Saving a copy credits the original author.
- **Ranking** — a global ranking (weekly and all-time) visible in the clients,
  showing display names only, never email addresses.
- **Levels and achievements** — neutral naming, unobtrusive notifications.
- **Weekly tasks** — a small rotating task list that resets once a week.

## Membership roster

Membership is managed through the API's admin roster endpoints under
`/v1/custom/admin/members`:

- `GET /v1/custom/admin/members` — the roster, with roles and statuses;
- `POST /v1/custom/admin/members` — register a member;
- `PATCH /v1/custom/admin/members/:memberId` — update roles or status.

Requests carry an optional `X-Tenant` header; an absent header resolves to the
default tenant and an invalid one is rejected with `400`. A member's roles are
a unique set — duplicates are removed preserving the first occurrence. Roster
responses expose public member fields only; internal identifiers never appear.

## Moderation

Moderation of community sign-ups (testers, developers, reports) is a single
authenticated endpoint, `POST /v1/custom/admin/community/review`. Its design
rules:

- **Fail closed.** The endpoint sits behind a reviewer authorization gate with
  an explicit allowlist of reviewer identities; when the allowlist cannot be
  evaluated, access is denied, not granted.
- **Identity from the session, never the body.** The reviewer's identity comes
  from the authenticated request context. A client-supplied identity in the
  request body is ignored.
- **Write by physical row.** Moderation outcomes are recorded back to the
  moderation worksheet by physical 1-based row position (header on row 1,
  data from row 2) — never by index computed after filtering, which is the
  off-by-one that historically produced spurious `400` responses.
- Hidden content is not deleted content: moderation can hide pending reports
  while preserving the original submission for later review.

## Tester reports

The public site shows a testers page fed by a community spreadsheet: a form
writes to the sheet, and the site reads its CSV export (the Google Sheets
`gviz` endpoint), parses it (RFC-4180-style quoting, CRLF and embedded
newlines), and renders tester reports with status per module. The sheet must
be shared so the CSV export is publicly readable; no credentials are embedded
in the site.

## Product invariants

- **Parity**: community features behave the same on web and desktop.
- **Privacy**: rankings and rosters show display names; email addresses are
  never displayed.
- **Moderation gate**: every moderation action requires an authorized
  reviewer session; there is no unauthenticated write path.
