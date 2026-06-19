# Doc sync audit

Code-grounded drift index for `fleet/gemoji-ship-with-proof-base` (2026-06-20).

## Summary

| Area | Items | Status |
|------|-------|--------|
| README | 5 | CLOSED via PR#6 |
| CONTRIBUTING | 3 | CLOSED via PR#5 |
| lib comments | 0 | n/a |
| AGENTS.md / CLAUDE.md | 0 | not present |

## DRIFT INDEX

| ID | Area | Doc location | Code truth | Status |
|----|------|--------------|------------|--------|
| D-001 | README | Registry API § | `Emoji.preload!` (`lib/emoji.rb:28-31`) | CLOSED via PR#6 |
| D-002 | README | Registry API § | `Emoji.remove_emoji` (`lib/emoji.rb:44-49`) | CLOSED via PR#6 |
| D-003 | README | Registry API § | `DuplicateAliasError`, `DataError` (`lib/emoji.rb:11-12`) | CLOSED via PR#6 |
| D-004 | README | Development § | Six-file `ruby -Ilib:test` harness | CLOSED via PR#6 |
| D-005 | README | Registry API § | Lazy catalog load on first lookup | CLOSED via PR#6 |
| D-006 | CONTRIBUTING | Prerequisites | Ruby `>= 2.7` in gemspec | CLOSED via PR#5 |
| D-007 | CONTRIBUTING | script/test | Both Rake and direct ruby paths documented | CLOSED via PR#5 |
| D-008 | CONTRIBUTING | preload note | `Emoji.preload!` for eager load | CLOSED via PR#5 |

## Broken links / commands

All documented test commands verified green (35 runs, 92 assertions). No broken internal links.

## Code bug findings (deferred)

None.