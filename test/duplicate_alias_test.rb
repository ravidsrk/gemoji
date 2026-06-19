require 'test_helper'

class DuplicateAliasTest < TestCase
  test "edit_emoji raises DuplicateAliasError when alias is taken by another emoji" do
    emoji = Emoji.create("duplicate_alias_dogfood_a")
    other = Emoji.create("duplicate_alias_dogfood_b")

    begin
      error = assert_raises(Emoji::DuplicateAliasError) do
        Emoji.edit_emoji(other) { |char| char.add_alias "duplicate_alias_dogfood_a" }
      end
      assert_match(/duplicate_alias_dogfood_a/, error.message)
      assert_match(/already used by/, error.message)
    ensure
      Emoji.remove_emoji(emoji)
      Emoji.remove_emoji(other)
    end
  end

  test "create raises DuplicateAliasError when new emoji reuses an existing alias" do
    emoji = Emoji.create("duplicate_alias_dogfood_existing")

    begin
      assert_raises(Emoji::DuplicateAliasError) do
        Emoji.create("duplicate_alias_dogfood_existing")
      end
      assert_equal emoji, Emoji.find_by_alias("duplicate_alias_dogfood_existing")
    ensure
      Emoji.remove_emoji(emoji)
    end
  end
end