# Adversarial review (fresh) — gemoji

Code-grounded review. Phase 0 output for `adversarial-review-and-fix` dogfood.

## Validated strengths (do not touch)

- Emoji JSON load + dedup/freeze strategy in `lib/emoji.rb`
- Unicode variation-selector handling and `TEXT_GLYPHS` exceptions
- Skin-tone variant generation in `lib/emoji/character.rb`
- Comprehensive data-file conformance test against `vendor/unicode-emoji-test.txt`

## Findings

| ID | Sev | Area | Problem | Fix | Acceptance |
|----|-----|------|---------|-----|------------|
| REL-001 | P1 | `test/emoji_test.rb:192` | `assert 0, custom.size` never asserts count (always fails condition `0`) | Use `assert_equal 0, custom.size` | Test passes; custom emoji count verified |
| REL-002 | P2 | `lib/emoji.rb` `edit_emoji` | Removing aliases does not clear `@names_index` / `@unicodes_index` stale keys | Rebuild index entries for emoji on edit (delete old keys for this emoji, re-add) | New test: removed alias returns nil from `find_by_alias` |
| REL-003 | P2 | `test/test_helper.rb:4` | `MiniTest::Test` breaks on stdlib `Minitest` (Ruby 3.4+/4.0) | Inherit `Minitest::Test` | `ruby -Ilib:test test/emoji_test.rb` runs green |

## Refuted

| ID | Reason |
|----|--------|
| SEC-001 | No network surface, secrets, or user input parsing in library core |

## Ranking

1. REL-001 (test correctness)
2. REL-003 (test harness portability)
3. REL-002 (index consistency)

## Hot files

- `lib/emoji.rb`
- `test/emoji_test.rb`
- `test/test_helper.rb`