# Adversarial Architecture Review — gemoji (fresh)

**Reviewer:** P0-REVIEW (code-grounded)  
**Skeptic:** P0-SKEPTIC — **PHASE: `REVIEW_FROZEN`** (see Skeptic verdict)  
**Scope:** `lib/**/*.rb`, `test/**/*.rb`, `db/**/*.rb`, gemspec/Gemfile/Rakefile, CI, README API surface  
**Repo:** `/private/tmp/gemoji` @ `4.1.0`  
**Method:** Direct source read + runtime validation (`ruby -Ilib` probes). No prior review docs consulted.

---

## Executive summary

gemoji is a small, well-scoped Unicode emoji lookup gem with a frozen JSON catalog, eager in-memory indexing, and solid data-integrity tests against `vendor/unicode-emoji-test.txt`. Core read paths (`find_by_alias`, `find_by_unicode` for canonical sequences, variation-selector normalization) are thoughtfully implemented.

The highest-risk gaps are **(1)** incomplete skin-tone normalization in `find_by_unicode`, **(2)** global mutable registry state without concurrency guards or a teardown primitive, **(3)** index/list desynchronization when consumers mutate or “pop” without `edit_emoji`, and **(4)** maintainer supply-chain fragility when regenerating `emoji.json`. None of these are catastrophic for the typical read-only Rails boot + lookup pattern, but they matter to consumers using `create`/`edit_emoji` at runtime or matching real-world skin-tone permutations.

---

## Skeptic verdict

**Reviewer:** P0-SKEPTIC (code re-verification + runtime probes)  
**PHASE:** `REVIEW_FROZEN` — findings frozen pending fix pass; severity adjustments below are skeptic-narrowed, not re-ranked in dependency table.

**Method:** Re-read every cited `file:line`, ran `ruby -Ilib` probes on Ruby 4.0.5 (boot ~397ms, mixed-tone lookup `nil`, `all.pop` ghost index confirmed, `gsub` simulation fixes all `raw_skin_tone_variants` round-trips).

### CONFIRMED (24)

| ID | Status | Skeptic severity | Notes |
|----|--------|------------------|-------|
| **DATA-001** | CONFIRMED | P1 | `sub` strips one Fitzpatrick codepoint; mixed-tone `people_holding_hands` → `nil`; `gsub` fix validated in probe |
| **COUP-001** | CONFIRMED | P1 | `VARIATION_SELECTOR_16` / `SKIN_TONES` / tone regex duplicated in `lib/emoji.rb`, `lib/emoji/character.rb`, `db/emoji-test-parser.rb` |
| **REL-002** | CONFIRMED | P1 | No `remove`/`destroy`; `edit_emoji` `delete_if` primitive exists and is the right fix anchor |
| **OPS-001** | CONFIRMED | P1 | `Rakefile:23` uses `http://` curl with no checksum |
| **REL-001** | CONFIRMED (narrowed) | **P2** ↓ | Real test-isolation bug (`find=true` after `all.pop`); not typical production path unless consumers misuse `all.pop` |
| **CONC-001** | CONFIRMED (narrowed) | **P2** ↓ | Theoretical corruption requires concurrent `create`/`edit_emoji`; read-only `find_by_*` stress-tested clean — downgrade from P1 for read-mostly default |
| **REL-003** | CONFIRMED (narrowed) | P2 | By-design mutable readers; desync is consumer contract violation, not silent corruption |
| **REL-004** | CONFIRMED | P2 | `create` with alias `smile` overwrites index to `dup_test` — probe confirmed |
| **REL-005** | CONFIRMED | P2 | `Emoji.all` at `lib/emoji.rb:141-142`; ~397ms boot tax on Ruby 4.0.5 |
| **REL-006** | CONFIRMED (narrowed) | **P3** ↓ | Valid shipped `emoji.json` is CI-tested; issue is error ergonomics for corrupt installs only |
| **CONC-002** | CONFIRMED (narrowed) | P2 | Defensive hardening; overlaps REL-003; freeze/dup fix must not break `add_alias` + `edit_emoji` (S-02) |
| **DATA-002** | CONFIRMED (narrowed) | P2 | Maintainer-time schema gap; broad tests (`emoji have category`, etc.) catch omissions in practice |
| **DATA-004** | CONFIRMED (narrowed) | P2 | Largely resolved by DATA-001 `gsub`; probe shows all `wave` + `people_holding_hands` variants round-trip after `gsub` |
| **SEC-001** | CONFIRMED (narrowed) | **P3** ↓ | Documented example escapes `<script>` (`test/documentation_test.rb:38-41`); `html_safe` is copy-paste hazard, not active XSS in shown code |
| **SEC-002** | CONFIRMED | P3 | `eval` on README excerpt is real; trusted local fixture, dev-only |
| **SEC-003** | CONFIRMED (narrowed) | P3 | Path traversal requires runtime `image_filename=` misuse; static catalog safe |
| **COST-001** | CONFIRMED (narrowed) | P2 | Inherent whole-catalog design; optional optimization tied to REL-005 |
| **OPS-002** | CONFIRMED | P2 | `Rakefile:23`, `db/dump.rb:41-42` hardcoded `15.0` / `16.4` |
| **OPS-003** | CONFIRMED | P2 | CI matrix 2.7–3.1; Ruby 4.0.5 `bundle exec rake` fails on `rake 10.3.2` / `ostruct` |
| **OPS-004** | CONFIRMED | P3 | `actions/checkout@v3` at `.github/workflows/test.yml:15` |
| **OPS-005** | CONFIRMED | P2 | CI runs tests only; `db/dump.rb` runs locally but not in workflow |
| **VER-001** | CONFIRMED | P2 | `required_ruby_version = '> 1.9'` vs CI floor 2.7 |
| **VER-002** | CONFIRMED | P3 | Ancient `rake`/`minitest` pins block Ruby 4.0 contributors |

**Fix soundness vs S-01–S-08:** DATA-001 `gsub` is isolated to lookup fallback and preserves S-01 indexing. REL-002 `remove_emoji` reuses S-02 `delete_if` pattern. COUP-001 extraction must copy constants verbatim. REL-005 lazy load defers but does not alter lookup semantics. CONC-001 freeze/lock must keep `edit_emoji` reindex path intact (S-02).

### REFUTED / DO-NOT-FIX (1)

| ID | Rationale |
|----|-----------|
| **DATA-003** | `create(nil)` is intentional bulk-load wiring; `Array(nil) == []` at `lib/emoji/character.rb:81` is idiomatic Ruby. No current failure, no planned validation in tree. Speculative “future `create` validation” is theoretical-only — not actionable for 4.1.0. |

### Skeptic-adjusted severity counts

| Severity | Original | Skeptic-confirmed |
|----------|----------|-------------------|
| P0 | 0 | 0 |
| P1 | 7 | **4** (DATA-001, COUP-001, REL-002, OPS-001) |
| P2 | 13 | **13** (includes REL-001, CONC-001 narrowed down from P1) |
| P3 | 5 | **6** (includes REL-006, SEC-001 narrowed down from P2) |

---

## Validated strengths (do-not-touch)

| # | Strength | Evidence |
|---|----------|----------|
| S-01 | **Variation-selector normalization is deliberate and tested** — generates qualified/unqualified aliases and respects `TEXT_GLYPHS` exceptions | `lib/emoji.rb:92-117`, `test/emoji_test.rb:33-41` |
| S-02 | **`edit_emoji` rebuilds indices via `delete_if` before re-insert** — correct pattern for alias/unicode churn | `lib/emoji.rb:35-45`, `test/emoji_test.rb:268-277` |
| S-03 | **String dedup/freeze via `-str` on Ruby ≥2.3** reduces memory for ~3.7k unicode alias strings | `lib/emoji.rb:84-90` |
| S-04 | **Unicode conformance test** cross-checks catalog vs `emoji-test.txt` | `test/emoji_test.rb:96-116` |
| S-05 | **Alias hygiene enforced in CI** — regex, duplicates, gender-pair completeness | `test/emoji_test.rb:66-94` |
| S-06 | **`raw_skin_tone_variants` documents and handles `people_holding_hands` special case** | `lib/emoji/character.rb:49-66`, `test/emoji_test.rb:180-187` |
| S-07 | **README XSS regression test** — `emojify` escapes HTML before substitution | `test/documentation_test.rb:38-41` |
| S-08 | **Frozen-string discipline** in runtime lib code (`# frozen_string_literal: true`) | `lib/gemoji.rb:1`, `lib/emoji/character.rb:1` |

---

## Dependency-ordered ranking

Fix higher rows before lower rows where noted. **FOUNDATION** items unblock multiple downstream fixes.

| Rank | ID | Severity | FOUNDATION? | Rationale |
|------|-----|----------|-------------|-----------|
| 1 | **COUP-001** | P1 | **YES** | Skin-tone / VS-16 constants duplicated in 3 files; any lookup/generator fix must land once |
| 2 | **DATA-001** | P1 | **YES** | `find_by_unicode` skin-tone logic must be correct before documenting or extending tone APIs |
| 3 | **REL-002** | P1 | **YES** | Formal remove/reindex primitive needed before safe test cleanup & runtime `create` usage |
| 4 | **CONC-001** | P1 | **YES** | Concurrency model must be decided before expanding mutation APIs |
| 5 | **REL-001** | P1 | no | Depends on REL-002 (`remove_emoji` or `edit_emoji` teardown) |
| 6 | **REL-003** | P2 | no | Depends on CONC-001 + documenting mutation contract |
| 7 | **REL-004** | P2 | no | Depends on REL-002 + validation hook in `create`/`edit_emoji` |
| 8 | **OPS-001** | P1 | no | Independent; blocks trustworthy `db:dump` regeneration |
| 9 | **OPS-002** | P2 | no | Depends on OPS-001 for reproducible Unicode pin |
| 10 | **COST-001** | P2 | no | Lazy-load is optional optimization after correctness |
| 11 | **DATA-002** | P2 | no | JSON schema hardening in `parse_data_file` |
| 12 | **SEC-001** | P2 | no | README contract clarification |
| 13 | **VER-001** | P2 | no | CI/gemspec alignment |
| 14 | **OPS-003** | P2 | no | CI matrix expansion |
| 15 | **SEC-002** | P3 | no | Test-only eval |
| 16 | **OPS-004** | P3 | no | Action version bump |
| 17 | **VER-002** | P3 | no | Dev-dep refresh |

---

## Hot-file collision map

| File | Finding IDs | Notes |
|------|-------------|-------|
| `lib/emoji.rb` | DATA-001, REL-001, REL-002, REL-003, REL-004, CONC-001, CONC-002, COST-001, DATA-002, COUP-001, REL-006 | **Primary collision hub** — 11 findings |
| `lib/emoji/character.rb` | CONC-002, COUP-001, DATA-004, SEC-003 | Skin-tone constants + mutable readers |
| `test/emoji_test.rb` | REL-001, DATA-001, REL-004 | Cleanup patterns + coverage gaps |
| `db/emoji-test-parser.rb` | COUP-001, OPS-002 | Generator/parser constant drift |
| `db/dump.rb` | OPS-002 | Hardcoded version defaults |
| `Rakefile` | OPS-001, OPS-002 | HTTP fetch + Unicode pin |
| `README.md` | SEC-001, SEC-003 | Consumer-facing patterns |
| `test/documentation_test.rb` | SEC-002 | `eval` of README |
| `gemoji.gemspec` | VER-001 | Ruby version policy |
| `Gemfile` | VER-002, OPS-003 | Dev dep pins |
| `.github/workflows/test.yml` | OPS-003, OPS-004, VER-001 | CI coverage |

---

## Findings

### REL-001 — `create` test teardown leaks index entries

**Skeptic status:** CONFIRMED (narrowed) — P2 (test isolation; not production unless `all.pop` misused)

| Field | Value |
|-------|-------|
| **Severity** | P1 → **P2** (skeptic) |
| **Tag** | CODE |
| **Area** | Reliability |

**Problem:** Tests that add runtime emoji clean up with `Emoji.all.pop` only, leaving `@names_index` / `@unicodes_index` entries pointing at objects no longer in `@all`. Subsequent lookups return “ghost” emoji. Validated: after `pop`, `Emoji.find_by_alias("music_test_cleanup")` still resolves.

**Evidence:**
- `test/emoji_test.rb:213-215` — `ensure` block calls `Emoji.all.pop` without reindex
- `test/emoji_test.rb:225-227`, `238-240` — same pattern in other `create` tests
- `lib/emoji.rb:23-26` — `create` always inserts into indices via `edit_emoji`
- Runtime probe: `find=true` after `all.pop`

**Fix:** Add `Emoji.remove_emoji(emoji)` (see REL-002) that `delete_if`s index entries and removes from `@all`. Replace test `ensure` blocks with `Emoji.remove_emoji(emoji)`. Reuse existing `edit_emoji` index deletion primitive at `lib/emoji.rb:35-36`.

**Acceptance criteria:**
- After each `create` test's `ensure`, `Emoji.find_by_alias(<created alias>)` returns `nil`
- `Emoji.all.size` equals pre-test count
- No new entries in `@names_index` / `@unicodes_index` for removed emoji (internal test or introspection helper)

---

### REL-002 — No supported teardown for runtime-created emoji

**Skeptic status:** CONFIRMED

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **Tag** | CODE |
| **Area** | Reliability |

**Problem:** Public API exposes `create` (README + `lib/emoji.rb:23-27`) but no symmetric `remove`/`destroy`. Consumers and tests cannot restore global registry state. Duplicate-alias overwrites (REL-004) become permanent without manual index surgery.

**Evidence:**
- `lib/emoji.rb:23-27` — `create` appends to `self.all` and indexes
- `README.md:54-74` — documents runtime `Emoji.create` as supported workflow
- No `remove`, `destroy`, or `delete` in `lib/**/*.rb`

**Fix:** Implement `Emoji.remove_emoji(emoji)`:
1. `@names_index.delete_if { |_, v| v == emoji }` (reuse `lib/emoji.rb:35-36` pattern)
2. `@unicodes_index.delete_if { |_, v| v == emoji }`
3. `@all.delete(emoji)`
Return `emoji` or `nil` if not found. Mirror `edit_emoji` structure.

**Acceptance criteria:**
- `Emoji.create("tmp") { ... }; Emoji.remove_emoji(e); Emoji.find_by_alias("tmp")` → `nil`
- README example apps can add/remove custom emoji in test suites without order-dependent leakage
- Unit test covers remove of indexed unicode aliases

---

### REL-003 — Direct array mutation bypasses index maintenance

**Skeptic status:** CONFIRMED (narrowed) — documented contract violation, not silent corruption

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Reliability |

**Problem:** `aliases`, `unicode_aliases`, and `tags` are exposed as mutable arrays (`attr_reader`). Consumers can `emoji.aliases << "foo"` without calling `edit_emoji`, desynchronizing indices. Validated: direct `<<` does not register in `find_by_alias`.

**Evidence:**
- `lib/emoji/character.rb:20`, `41`, `74` — `attr_reader` on array fields
- `lib/emoji.rb:31-48` — index updates only inside `edit_emoji`
- Runtime probe: `aliases << "direct_mutation_alias"` → `find_by_alias` returns `nil`

**Fix (minimal):** Document that all alias/unicode/tag mutations must go through `add_*` methods followed by `Emoji.edit_emoji(emoji) {}`. **Better fix:** Freeze arrays after `edit_emoji`/`parse_data_file` completes; unfreeze/copy-on-write inside `edit_emoji` block. Reuse `edit_emoji` as the single reindex primitive (`lib/emoji.rb:31-48`).

**Acceptance criteria:**
- Mutating returned alias arrays without `edit_emoji` either raises `FrozenError` or is documented with a failing test demonstrating the contract
- `add_alias` + `edit_emoji` remains the supported path (existing tests pass)

---

### REL-004 — Duplicate alias `create` silently overwrites index (last-wins)

**Skeptic status:** CONFIRMED — runtime probe: `find_by_alias("smile")` → `dup_test`

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Reliability |

**Problem:** `create` with an alias already bound to another emoji overwrites `@names_index[name]` with no warning. `find_by_alias("smile")` then points at the newcomer. Validated via runtime `create` with alias `"smile"`.

**Evidence:**
- `lib/emoji.rb:40-42` — unconditional `@names_index[name] = emoji`
- `test/emoji_test.rb:89-92` — duplicate detection exists only for static JSON data, not runtime `create`
- Runtime probe: after `create` with alias `smile`, lookup returns `dup_test`

**Fix:** In `edit_emoji`, before assignment, check `existing = @names_index[name]`; if `existing && existing != emoji`, raise `Emoji::DuplicateAliasError` (new exception) or warn per Ruby conventions. Reuse duplicate-detection logic pattern from `test/emoji_test.rb:89-92`.

**Acceptance criteria:**
- `Emoji.create("x") { |c| c.add_alias("smile") }` raises when `smile` already indexed
- Static JSON load still passes duplicate alias test
- Error message includes conflicting alias and both emoji names

---

### REL-005 — Eager `Emoji.all` preload on require adds ~300ms boot tax

**Skeptic status:** CONFIRMED — probe: ~397ms on Ruby 4.0.5

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Reliability / Cost |

**Problem:** Requiring the gem always parses ~413KB `db/emoji.json` (~1,870 emoji, ~3,751 unicode aliases) and builds indices before any lookup. Cold `require "gemoji"` measured ~296ms (Ruby 4.0, local). Consumers that only need a subset still pay full parse cost at boot.

**Evidence:**
- `lib/emoji.rb:141-142` — unconditional `Emoji.all` at file bottom
- `lib/emoji.rb:79-82` — `JSON.parse(file.read)` loads entire file
- `db/emoji.json` — 413,367 bytes / 23,479 lines
- Runtime: 1,870 emoji, 3,751 unicode alias strings indexed

**Fix:** Remove bottom preload; rely on existing memoization in `all` / `names_index` / `unicodes_index` (`lib/emoji.rb:14-18`, `130-137`). Optionally add `Emoji.preload!` for consumers wanting eager load. Reuse existing lazy `defined? @all` guard.

**Acceptance criteria:**
- `require "gemoji"` does not call `parse_data_file` (verified via hook or absence of `@all`)
- First `Emoji.find_by_alias` triggers load; subsequent calls use cache
- Boot-time benchmark improves measurably in test harness

---

### REL-006 — `parse_data_file` has no error boundary; malformed JSON fails gem load

**Skeptic status:** CONFIRMED (narrowed) — P3 (error ergonomics; shipped JSON CI-validated)

| Field | Value |
|-------|-------|
| **Severity** | P2 → **P3** (skeptic) |
| **Tag** | CODE |
| **Area** | Reliability |

**Problem:** Any corrupt `emoji.json` shipped in the gem raises during `require`, bricking the host app at boot with an uncontextualized `JSON::ParserError`.

**Evidence:**
- `lib/emoji.rb:79-82` — bare `JSON.parse(file.read)`
- `lib/emoji.rb:141-142` — parse invoked eagerly on require

**Fix:** Wrap parse in `rescue JSON::ParserError => e` and re-raise `Emoji::DataError, "Failed to parse #{data_file}: #{e.message}"`. Reuse `data_file` helper (`lib/emoji.rb:10-12`) for path in message.

**Acceptance criteria:**
- Truncated/invalid `emoji.json` raises `Emoji::DataError` with file path
- Valid JSON still loads all emoji

---

### CONC-001 — Global mutable registry without synchronization

**Skeptic status:** CONFIRMED (narrowed) — P2 (only concurrent `create`/`edit_emoji`; read-only stress clean)

| Field | Value |
|-------|-------|
| **Severity** | P1 → **P2** (skeptic) |
| **Tag** | CODE |
| **Area** | Concurrency |

**Problem:** `@all`, `@names_index`, and `@unicodes_index` are ordinary hashes/arrays mutated by `create`/`edit_emoji` with no mutex. Under multi-threaded app servers (Puma, Sidekiq loading the gem), concurrent `create`/`edit_emoji` can interleave `delete_if` + reinsert steps and corrupt indices.

**Evidence:**
- `lib/emoji.rb:14-18` — mutable `@all`
- `lib/emoji.rb:32-45` — non-atomic index rebuild
- `lib/emoji.rb:23-27` — public mutation API
- No `Mutex`, `Monitor`, or freeze-after-load guard in `lib/**/*.rb`

**Fix:** **Option A (boring, recommended):** Document registry as load-time immutable; freeze `@all` and indices after initial parse; `create`/`edit_emoji` copy-on-write or raise in frozen mode. **Option B:** Wrap `create`/`edit_emoji` in `@mutex.synchronize` (new `Mutex` on module). Reuse `edit_emoji` as single critical section.

**Acceptance criteria:**
- Concurrent stress test (e.g., 10 threads × 100 `find_by_alias`) returns consistent results
- If freeze strategy: `create` after load raises clear error unless `Emoji.reset!` test helper exists
- Read-only `find_by_*` remain lock-free

---

### CONC-002 — Mutable collection readers allow unsynchronized cross-thread mutation

**Skeptic status:** CONFIRMED (narrowed) — defensive hardening; overlaps REL-003

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Concurrency |

**Problem:** Even with CONC-001 addressed, exposing live `Array` references lets thread A mutate `emoji.tags` while thread B iterates `Emoji.all`, causing `ArrayModifiedException`-class bugs in consumers.

**Evidence:**
- `lib/emoji/character.rb:20`, `41`, `74` — `attr_reader` returns internal arrays
- `lib/emoji.rb:14-18` — `Emoji.all` returns internal `@all` array directly

**Fix:** Return dup/frozen copies: `def aliases; @aliases.dup.freeze end` (or `.freeze` on stored arrays after load). For `Emoji.all`, return `@all.dup.freeze` or `Enumerable` wrapper. Reuse dedup/freeze lambda pattern from `lib/emoji.rb:84-90`.

**Acceptance criteria:**
- `emoji.aliases << "x"` raises `FrozenError` (or mutates copy without affecting index)
- `Emoji.all << x` does not alter internal registry

---

### DATA-001 — `find_by_unicode` strips only one Fitzpatrick modifier

**Skeptic status:** CONFIRMED — probe: mixed-tone → `nil`; `gsub` simulation → `people_holding_hands`

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **Tag** | CODE |
| **Area** | Data model |

**Problem:** Fallback lookup uses `String#sub` (single replacement), not `gsub`. Multi-person sequences with different skin tones on each person — common real-world input — fail lookup. Validated: `👩🏻‍🤝‍👩🏽` (`1f9d1-1f3fb-200d-1f91d-200d-1f9d1-1f3fc`) returns `nil`; base without tones resolves correctly.

**Evidence:**
- `lib/emoji.rb:56-57` — `unicode.sub(SKIN_TONE_RE, "")` (one modifier only)
- `test/emoji_test.rb:168-169` — tests single-modifier case only (`\u{1f44b}\u{1f3ff}`)
- `lib/emoji/character.rb:49-50` — documents incomplete permutation coverage for multi-person tones
- Runtime probe: mixed-tone `people_holding_hands` variant → `nil`

**Fix:** Replace `sub` with `gsub(SKIN_TONE_RE, "")` for fallback key. Extract shared `SKIN_TONE_RE` to COUP-001 resolution. Add test case mirroring `test/emoji_test.rb:180-187` but for `find_by_unicode` on mixed-tone input. Reuse `SKIN_TONE_RE` at `lib/emoji.rb:62`.

**Acceptance criteria:**
- `Emoji.find_by_unicode("\u{1f9d1}\u{1f3fb}\u{200d}\u{1f91d}\u{200d}\u{1f9d1}\u{1f3fc}")` returns `people_holding_hands`
- Existing single-tone tests (`test/emoji_test.rb:168-169`) still pass
- Document that not all permutations are indexed — only tone-stripped normalization

---

### DATA-002 — Partial JSON schema validation; missing keys become silent `nil`

**Skeptic status:** CONFIRMED (narrowed) — maintainer-time; broad tests catch omissions

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Data model |

**Problem:** `parse_data_file` uses `fetch` for `:aliases` and `:tags` but direct key access for `:category`, `:description`, `:unicode_version`, `:ios_version`, `:emoji`. Omitting required fields in `emoji.json` loads successfully with `nil` metadata, failing only if tests catch specific emoji.

**Evidence:**
- `lib/emoji.rb:100` — `fetch(:aliases)`
- `lib/emoji.rb:119` — `fetch(:tags)`
- `lib/emoji.rb:121-124` — `raw_emoji[:category]` etc. without `fetch`
- `test/emoji_test.rb:118-158` — category/description/ios_version tests exist but are broad, not per-entry schema

**Fix:** Use `fetch` for required keys with descriptive `KeyError` messages, or validate each entry against a minimal schema hash before `create`. Reuse `fetch` pattern already used for `:aliases`/`:tags`.

**Acceptance criteria:**
- Entry missing `:category` raises during `parse_data_file` with index/alias context
- Current valid `emoji.json` loads without error
- Custom emoji entries without `:emoji` key remain supported (optional field)

---

### DATA-003 — `create(nil)` in parser is a footgun

**Skeptic status:** REFUTED — `Array(nil)` is deliberate; no current or planned failure

| Field | Value |
|-------|-------|
| **Severity** | P3 (do-not-fix) |
| **Tag** | CODE |
| **Area** | Data model |

**Problem:** `parse_data_file` calls `self.create(nil)` (`lib/emoji.rb:99`). This works today because `Array(nil) == []` (`lib/emoji/character.rb:81`), but passing `nil` to a name-bearing constructor is fragile — future validation in `create` could break JSON load.

**Evidence:**
- `lib/emoji.rb:99` — `self.create(nil)`
- `lib/emoji/character.rb:80-81` — `@aliases = Array(name)`

**Fix:** Use `Emoji::Character.new` + `edit_emoji` internally for bulk load, or `create(raw_emoji.fetch(:aliases).first)` after aliases known. Reuse `edit_emoji` (`lib/emoji.rb:31-48`).

**Acceptance criteria:**
- `parse_data_file` does not call `create(nil)`
- Loaded emoji count unchanged; all `name` values non-nil

---

### DATA-004 — `raw_skin_tone_variants` vs `find_by_unicode` behavior gap

**Skeptic status:** CONFIRMED (narrowed) — subsumed by DATA-001 `gsub`; all variants round-trip in probe

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Data model |

**Problem:** `raw_skin_tone_variants` generates toned sequences, but `find_by_unicode` cannot round-trip many of them (especially mixed-tone). Consumers may generate variants via API then fail to resolve them.

**Evidence:**
- `lib/emoji/character.rb:51-66` — generates 5 variants per skin-tone emoji
- `lib/emoji.rb:56-57` — lookup normalizes at most one tone
- `test/emoji_test.rb:160-187` — tests generation, not reverse lookup for each variant

**Fix:** After DATA-001 `gsub` fix, add parameterized test: for each `skin_tones?` emoji, `find_by_unicode(variant)` returns parent for all `raw_skin_tone_variants` outputs. Reuse `raw_skin_tone_variants` (`lib/emoji/character.rb:51-66`) as test oracle.

**Acceptance criteria:**
- For `wave`, all 5 generated variants resolve via `find_by_unicode`
- For `people_holding_hands`, same-tone variants resolve (mixed-tone documented as limitation if not fixable)

---

### SEC-001 — README `html_safe` pattern negates XSS escaping

**Skeptic status:** CONFIRMED (narrowed) — P3 (documented example escapes script; copy-paste hazard only)

| Field | Value |
|-------|-------|
| **Severity** | P2 → **P3** (skeptic) |
| **Tag** | CODE+OPS |
| **Area** | Security |

**Problem:** Documented Rails helper calls `.html_safe` on the entire substituted string. If `:alias:` substitution ever bypasses `h()` (custom emoji filenames, future raw HTML in alt), consumer apps mark attacker-controlled HTML safe.

**Evidence:**
- `README.md:27-33` — `h(content)...gsub(...).html_safe`
- `test/documentation_test.rb:38-41` — confirms `<script>` escaped, but still marks output `html_safe`

**Fix:** Document safe usage: wrap only image tags, or use `sanitize` allowlist. Prefer returning safe buffer without `html_safe` on whole string. Reuse test pattern from `test/documentation_test.rb:38-41` to assert safe subset.

**Acceptance criteria:**
- README shows `html_safe` only on img fragment, or uses Rails `sanitize` with explicit tags
- Documentation test updated to match recommended pattern
- Escaping test for `<script>` still passes

---

### SEC-002 — `eval` on README excerpt in tests

**Skeptic status:** CONFIRMED — dev-only, trusted README fixture

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **Tag** | CODE |
| **Area** | Security |

**Problem:** Test loads README module via `eval`, which is brittle and would execute arbitrary code if README were compromised.

**Evidence:**
- `test/documentation_test.rb:4-6` — `eval docs.match(/^module.+?^end/m)[0]`

**Fix:** Replace `eval` with `Module.new` + `class_eval` of matched body, or extract `EmojiHelper` to `lib/` example file required by test. Reuse regex extraction already present.

**Acceptance criteria:**
- No `eval` in `test/documentation_test.rb`
- Documentation tests still pass

---

### SEC-003 — Custom `image_filename` / alias values flow into HTML `src` unvalidated

**Skeptic status:** CONFIRMED (narrowed) — runtime `create` misuse only; doc note sufficient

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **Tag** | CODE+OPS |
| **Area** | Security |

**Problem:** README builds `<img src="...#{emoji.image_filename}">` from gem data. Custom `image_filename` or alias-controlled paths are not validated; `../` segments could escape asset root in poorly configured apps.

**Evidence:**
- `README.md:29` — interpolates `emoji.image_filename` into `src`
- `lib/emoji/character.rb:96-104` — `image_filename` accepts arbitrary writer value
- `lib/emoji/character.rb:122-128` — default uses `name` without sanitization

**Fix:** Document that consumers must validate/sanitize `image_filename` before URL generation. Optionally add `image_filename` guard rejecting `..`, leading `/`, and `://`. Reuse `default_image_filename` structure.

**Acceptance criteria:**
- README security note present
- Optional: `image_filename = "../etc/passwd"` raises `ArgumentError`

---

### COST-001 — Full-catalog memory residency with no lazy/partial load

**Skeptic status:** CONFIRMED (narrowed) — acceptable design tradeoff; ties to REL-005

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE |
| **Area** | Cost / Abuse |

**Problem:** Every process holds full emoji catalog + dual hash indices in memory for app lifetime. No API to load categories/tags subsets. Acceptable for most apps, but wasteful for minimal consumers (e.g., CLI that looks up one emoji).

**Evidence:**
- `lib/emoji.rb:14-18`, `130-137` — whole-catalog memoization
- `lib/emoji.rb:141-142` — eager load
- ~1,914 alias keys + ~3,751 unicode keys (runtime count)

**Fix:** See REL-005 lazy load. Longer term: optional category-filtered load from partitioned JSON. Reuse `parse_data_file` loop (`lib/emoji.rb:98-127`).

**Acceptance criteria:**
- Lazy load implemented (REL-005)
- Memory profiling doc note for maintainers

---

### OPS-001 — Unicode data fetched over HTTP without integrity check

**Skeptic status:** CONFIRMED — `Rakefile:23` `http://` curl, no checksum

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **Tag** | CODE+OPS |
| **Area** | Ops |

**Problem:** `rake db:generate` downloads `emoji-test.txt` over **HTTP** with no checksum, signature, or version pinning beyond URL path. MITM or CDN compromise could poison maintainer regeneration of `emoji.json`.

**Evidence:**
- `Rakefile:22-24` — `curl -fsSL 'http://unicode.org/Public/emoji/15.0/emoji-test.txt'`

**Fix:** Switch to `https://unicode.org/...`, pin SHA256 of known-good `vendor/unicode-emoji-test.txt` in `Rakefile`, verify after download. Reuse existing `vendor/unicode-emoji-test.txt` as golden hash source. Fail task on mismatch.

**Acceptance criteria:**
- Rake task uses HTTPS
- `rake db:generate` verifies checksum; wrong hash aborts with clear message
- Committed vendor file hash matches pin

---

### OPS-002 — Unicode / iOS version strings hardcoded in tooling

**Skeptic status:** CONFIRMED

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE+OPS |
| **Area** | Ops |

**Problem:** Rake pins Unicode **15.0**; `db/dump.rb` assigns `unicode_version: "15.0"` and `ios_version: "16.4"` to newly discovered emoji. Drift between catalog, vendor file, and defaults silently produces stale metadata.

**Evidence:**
- `Rakefile:23` — `emoji/15.0/emoji-test.txt`
- `db/dump.rb:41-42` — hardcoded `"15.0"` / `"16.4"`
- `gemoji.gemspec:3` — gem version `4.1.0` unrelated to Unicode version

**Fix:** Centralize `UNICODE_VERSION` constant in `db/` or `Rakefile`, interpolate into URL and dump defaults. Reuse `EmojiTestParser` version comment extraction (`db/dump.rb:24` already strips `E15.0`-style prefixes from descriptions).

**Acceptance criteria:**
- Single constant drives Rake URL and dump defaults
- Regenerated JSON carries consistent `unicode_version` for new entries

---

### OPS-003 — CI Ruby matrix stale; dev toolchain breaks on Ruby 4.0

**Skeptic status:** CONFIRMED — Ruby 4.0.5 `bundle exec rake` → `LoadError: ostruct`

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE+OPS |
| **Area** | Ops |

**Problem:** CI tests Ruby 2.7–3.1 only (`.github/workflows/test.yml:10`). `gemoji.gemspec:7` claims `> 1.9` with no upper policy. Local Ruby 4.0 fails: `rake 10.3.2` cannot load `ostruct` (stdlib gem split).

**Evidence:**
- `.github/workflows/test.yml:10` — `ruby: ["2.7", "3.0", "3.1"]`
- `gemoji.gemspec:7` — `required_ruby_version = '> 1.9'`
- `Gemfile:3-4` — `rake ~> 10.3.2`, `minitest ~> 5.3.5`
- Local `bundle exec rake` → `LoadError: cannot load such file -- ostruct`

**Fix:** Expand matrix to 3.2, 3.3, 3.4 (and 4.0 if supported); bump `rake` to ≥13 and `minitest` to ≥5.25; set `required_ruby_version` to `>= 2.7` matching CI floor. Reuse existing `bundle exec rake` workflow step.

**Acceptance criteria:**
- CI green on Ruby 3.2+ and locally on Ruby 4.0
- `gemfile`/`gemspec` Ruby requirement matches tested floor
- `bundle exec rake` passes

---

### OPS-004 — GitHub Actions `checkout@v3` outdated

**Skeptic status:** CONFIRMED

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **Tag** | CODE+OPS |
| **Area** | Ops |

**Problem:** Workflow uses `actions/checkout@v3`; v4 is current and receives security fixes.

**Evidence:**
- `.github/workflows/test.yml:15` — `actions/checkout@v3`

**Fix:** Bump to `actions/checkout@v4`.

**Acceptance criteria:**
- Workflow uses `@v4`; CI passes unchanged

---

### OPS-005 — CI does not exercise `db:dump` regeneration path

**Skeptic status:** CONFIRMED — workflow runs `bundle exec rake` only; `db/dump.rb` works locally

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE+OPS |
| **Area** | Ops |

**Problem:** Tests validate loaded `emoji.json` against vendored `unicode-emoji-test.txt`, but CI never runs `rake db:dump` to ensure generator scripts (`db/dump.rb`, `db/emoji-test-parser.rb`) remain functional. Parser drift could break maintainers silently until manual regen.

**Evidence:**
- `Rakefile:17-19` — `db:dump` task exists
- `.github/workflows/test.yml:23-24` — only `bundle exec rake` (tests)
- `test/emoji_test.rb:96-116` — read-only cross-check

**Fix:** Add CI job step `bundle exec rake db:dump > /tmp/emoji.json && diff -q /tmp/emoji.json db/emoji.json` (or allow deterministic diff). Reuse `EmojiTestParser` path from tests.

**Acceptance criteria:**
- CI fails if `db:dump` exits non-zero
- CI fails if regenerated output diverges from committed `emoji.json` (unless Unicode bump PR)

---

### COUP-001 — Duplicated Unicode constants across runtime and generator code

**Skeptic status:** CONFIRMED — three independent definitions verified

| Field | Value |
|-------|-------|
| **Severity** | P1 |
| **Tag** | CODE |
| **Area** | Coupling |

**Problem:** `VARIATION_SELECTOR_16`, `SKIN_TONES`, and skin-tone regex logic are independently defined in `lib/emoji.rb`, `lib/emoji/character.rb`, and `db/emoji-test-parser.rb`. Divergence risks parser/generator/runtime lookup mismatches. Tests already reach into private `TEXT_GLYPHS` via `const_get`.

**Evidence:**
- `lib/emoji.rb:61-62` — `VARIATION_SELECTOR_16`, `SKIN_TONE_RE`
- `lib/emoji/character.rb:108-118` — `VARIATION_SELECTOR_16`, `SKIN_TONES`
- `db/emoji-test-parser.rb:4-12` — duplicate constants
- `test/emoji_test.rb:99` — `Emoji.const_get(:TEXT_GLYPHS)`

**Fix:** Extract `lib/emoji/unicode.rb` (or `db/unicode_constants.rb` required by both) defining shared constants module `Emoji::Unicode`. Replace local copies. Reuse existing constant values verbatim.

**Acceptance criteria:**
- Single source of truth for `SKIN_TONES`, `VARIATION_SELECTOR_16`, `SKIN_TONE_RE`
- All tests + `db:dump` pass
- No `const_get` needed in tests for `TEXT_GLYPHS` (make test-visible or public)

---

### VER-001 — `required_ruby_version '> 1.9'` is meaningless

**Skeptic status:** CONFIRMED

| Field | Value |
|-------|-------|
| **Severity** | P2 |
| **Tag** | CODE+OPS |
| **Area** | Version hygiene |

**Problem:** Gemspec permits Ruby versions never tested and below language features the code assumes (`-str` freeze dedup, unicode regex syntax). Misleads Bundler resolution.

**Evidence:**
- `gemoji.gemspec:7` — `'> 1.9'`
- `lib/emoji.rb:84-87` — relies on `String#-@` (Ruby ≥2.3)
- `.github/workflows/test.yml:10` — floor is 2.7

**Fix:** Set `s.required_ruby_version = '>= 2.7'` to match CI. Document in README if needed.

**Acceptance criteria:**
- Gemspec requirement matches CI minimum
- Bundle on Ruby 2.6 fails fast with clear message

---

### VER-002 — Ancient dev dependency pins block modern Ruby

**Skeptic status:** CONFIRMED — `rake ~> 10.3.2` blocks Ruby 4.0

| Field | Value |
|-------|-------|
| **Severity** | P3 |
| **Tag** | CODE+OPS |
| **Area** | Version hygiene |

**Problem:** `rake ~> 10.3.2` predates Ruby 3.4+/4.0 stdlib gem extraction; blocks contributors on current Ruby.

**Evidence:**
- `Gemfile:3-4` — `rake ~> 10.3.2`, `minitest ~> 5.3.5`
- Local Ruby 4.0 `bundle exec rake` failure

**Fix:** Relax pins: `rake >= 13`, `minitest >= 5.25`. Keep `i18n` constraint or move to `db/Gemfile` optional group.

**Acceptance criteria:**
- `bundle install && bundle exec rake` succeeds on Ruby 3.3 and 4.0
- CI still passes on 2.7 if retained, or floor raised per VER-001

---

## Summary statistics

| Severity | Original | Skeptic-confirmed |
|----------|----------|-------------------|
| **P0** | 0 | 0 |
| **P1** | 7 | **4** |
| **P2** | 13 | **13** |
| **P3** | 5 | **6** |
| **Refuted** | — | **1** (DATA-003) |
| **Total** | **25** | **24 confirmed + 1 refuted** |

### Top 5 P0/P1 finding IDs

1. **DATA-001** — single skin-tone `sub` breaks mixed-tone `find_by_unicode`
2. **COUP-001** — duplicated Unicode constants (FOUNDATION)
3. **CONC-001** — unsynchronized global mutation (FOUNDATION)
4. **REL-002** — no `remove_emoji` teardown (FOUNDATION)
5. **OPS-001** — HTTP Unicode fetch without integrity check

### FOUNDATION finding IDs

- **COUP-001**
- **DATA-001**
- **REL-002**
- **CONC-001**

### Validated strengths count

**8** (see do-not-touch table)

---

## Assumptions

1. Typical production usage is **read-mostly** after boot (Rails initializer requires gem once); mutation APIs are secondary but publicly documented.
2. Review targets gem **4.1.0** as shipped; Unicode 15.0 vendor file is authoritative for conformance tests.
3. Findings prioritize consumer-visible correctness and maintainer regeneration safety over theoretical scale concerns.
4. No P0 assigned: no evidence of exploitable remote attack surface in the library itself; security findings are integration/documentation footguns.