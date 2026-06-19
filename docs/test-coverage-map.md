# Test coverage map — gemoji

Generated: 2026-06-20
Framework: stdlib Minitest (`test/test_helper.rb`, `define_method` style `test "..."`)
Commands:
```bash
ruby -Ilib:test test/emoji_test.rb
ruby -Ilib:test test/documentation_test.rb
```

## Baseline (pre-mission)

| File | Runs | Assertions |
|------|------|------------|
| test/emoji_test.rb | 23 | 63 |
| test/documentation_test.rb | 4 | 4 |
| **Total** | **27** | **67** |

## Undertested areas (by importance)

### P1 — core registry integrity

| Module | Behaviour | Risk | Existing tests |
|--------|-----------|------|----------------|
| `lib/emoji.rb` | `edit_emoji_unsafe` raises `DuplicateAliasError` when alias collides | Silent index corruption | none |
| `lib/emoji.rb` | `parse_data_file` raises `DataError` on malformed JSON | Opaque load failures | none |

### P2 — concurrency & security

| Module | Behaviour | Risk | Existing tests |
|--------|-----------|------|----------------|
| `lib/emoji.rb` | `registry_synchronize` / `@registry_mutex` under threaded load | Race on indices | none |
| `lib/emoji/character.rb` | `image_filename=` rejects `..` and `://` (SEC-003) | Path traversal in consumers | none |

### P3 — already adequate

| Area | Notes |
|------|-------|
| find_by_alias / find_by_unicode | broad data + edge cases |
| create / edit / remove_emoji | covered with ensure teardown |
| skin tones / unicode aliases | extensive |
| README EmojiHelper | documentation_test.rb |

## Planned PR units

One PR per gap area (separate test files → parallel-safe, no hot-file conflict):

1. `test/duplicate_alias_test.rb` — T-COVER-duplicate-alias
2. `test/data_error_test.rb` — T-COVER-data-error
3. `test/registry_concurrency_test.rb` — T-COVER-concurrency
4. `test/image_filename_test.rb` — T-COVER-image-filename

## Out of scope (defer)

- Changing application logic for testability
- Coverage percentage tooling (no simplecov in repo; count runs/assertions instead)
- Regenerating `db/emoji.json`