---
fleet-outcome:
  mission: doc-sync
  status: done
  repo: /private/tmp/gemoji
  base_branch: fleet/gemoji-ship-with-proof-base
  prs_merged: 3
  metrics:
    drift_open: 0
    code_bug_findings: 1
  deferred_missions:
    - id: bug-batch
      reason: "registry_concurrency_test.rb flakes on Ruby 4.0.5 — names_index nil race during concurrent find_by_alias while lazy-loading"
      blocker: null
  run:
    duration_min: 20
    coordinator_turns: 1
    worker_retries: 0
---

# Doc sync readiness

## Summary

Fresh audit found 8 doc-vs-code discrepancies (prior run lacked `doc-sync-progress.md`).
All drift items closed via three merge commits into `fleet/gemoji-ship-with-proof-base`.

| PR | Branch | Areas |
|----|--------|-------|
| [#5](https://github.com/ravidsrk/gemoji/pull/5) | `fleet/doc-sync-contributing` | CONTRIBUTING Ruby 2.7+, test paths, preload! |
| [#6](https://github.com/ravidsrk/gemoji/pull/6) | `fleet/doc-sync-readme` | Registry API, errors, full test harness |
| [#7](https://github.com/ravidsrk/gemoji/pull/7) | `fleet/doc-sync-final` | Audit, progress ledger, readiness |

## Changes

- **README:** `Registry API` section (`preload!`, `remove_emoji`, lazy load, exceptions); Development lists all six test files and Ruby 2.7+
- **CONTRIBUTING:** Prerequisites aligned with gemspec; documents `script/test` and `ruby -Ilib:test`; notes `preload!` for eager load

## Verification

```bash
ruby -Ilib:test test/emoji_test.rb
ruby -Ilib:test test/documentation_test.rb
ruby -Ilib:test test/duplicate_alias_test.rb
ruby -Ilib:test test/data_error_test.rb
ruby -Ilib:test test/registry_concurrency_test.rb
ruby -Ilib:test test/image_filename_test.rb
```

Five of six files pass on local Ruby 4.0.5; `registry_concurrency_test.rb` errors with
`NoMethodError` on `names_index[name]` under concurrent lazy load (code bug, not doc drift).
CI matrix Ruby 2.7–3.1 is authoritative per DECISIONS.md.

## Code bug finding (deferred)

| ID | Finding | Location |
|----|---------|----------|
| CONC-DOC-001 | Concurrent `find_by_alias` can read `names_index` before `parse_data_file` finishes | `lib/emoji.rb:60-61`, `test/registry_concurrency_test.rb:4-18` |

## Recommended next missions

| Mission | Reason |
|---------|--------|
| `bug-batch` | Fix CONC-DOC-001 lazy-load race under concurrent lookup |