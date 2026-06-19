require 'test_helper'

class ImageFilenameTest < TestCase
  test "image_filename rejects path traversal segments" do
    emoji = Emoji.create("image_filename_dogfood")

    begin
      error = assert_raises(ArgumentError) do
        emoji.image_filename = "../etc/passwd"
      end
      assert_match(/invalid image_filename/, error.message)
    ensure
      Emoji.remove_emoji(emoji)
    end
  end

  test "image_filename rejects URL schemes" do
    emoji = Emoji.create("image_filename_url_dogfood")

    begin
      error = assert_raises(ArgumentError) do
        emoji.image_filename = "https://evil.example/emoji.png"
      end
      assert_match(/invalid image_filename/, error.message)
    ensure
      Emoji.remove_emoji(emoji)
    end
  end

  test "image_filename accepts safe relative paths" do
    emoji = Emoji.create("image_filename_safe_dogfood") do |char|
      char.image_filename = "assets/custom/emoji.png"
    end

    begin
      assert_equal "assets/custom/emoji.png", emoji.image_filename
    ensure
      Emoji.remove_emoji(emoji)
    end
  end
end