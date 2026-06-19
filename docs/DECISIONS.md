# Fleet decisions

## Setup (external dogfood)

- REPO: github/gemoji clone at `/tmp/gemoji`
- Campaign: `external-gemoji-ship-with-proof` (ship-with-proof)
- BASE: `fleet/gemoji-ship-with-proof-base`
- Adapter: `autonomous-fleet-adapter-grok`
- BRANCH_PREFIX: `fleet/`
- Community: gstack post-gates skipped (no staging URL)

## Mission: adversarial-review-and-fix (2026-06-20)

- MAINTAINER: Ravindra Kumar <ravidsrk@gmail.com>
- Worker mode: fully autonomous / max effort
- Merge policy: merge commit into BASE, never squash
- Local Ruby 4.0.5 incompatible with pinned rake/minitest; CI matrix 2.7–3.1 is authoritative for test green
- Fresh run: ignore any prior review docs; output `docs/adversarial-review-fresh.md`

ASSUMPTIONS:
1. Scope: gemoji library code (`lib/`, `test/`, `db/`, gemspec, CI) — not upstream emoji data regeneration
2. Stack: Ruby gem, minitest, JSON emoji DB; no runtime server or secrets surface
3. OUT OF scope: BASE→main promotion, deploy, live infra apply, regenerating `db/emoji.json` from Unicode
→ Proceeding unless a hard-dependency gate blocks.

## Mission: test-coverage (2026-06-20)

- MAINTAINER: Ravindra Kumar <ravidsrk@gmail.com>
- BASE: `fleet/gemoji-ship-with-proof-base`
- Worker mode: fully autonomous / max effort
- Merge policy: merge commit into BASE, never squash
- Prior readiness doc existed but progress ledger was missing; re-running T-MAP confirmed 4 open gaps from arch-build-readiness recommendations
- Test command: `ruby -Ilib:test test/<file>_test.rb` (Ruby 4.0.5 local; CI matrix 2.7–3.1 authoritative)
- DataError tested via subprocess to avoid polluting loaded registry in main suite

ASSUMPTIONS:
1. Scope: add behaviour tests only in `test/` — no `lib/` changes
2. Stack: minitest, stdlib JSON; separate test files per gap for parallel PR safety
3. OUT OF scope: coverage % vanity targets, logic refactors, BASE→main promotion
→ Proceeding unless a hard-dependency gate blocks.