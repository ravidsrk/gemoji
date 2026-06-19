require 'test_helper'

class RegistryConcurrencyTest < TestCase
  test "concurrent find_by_alias from multiple threads returns consistent results" do
    errors = []
    mutex = Mutex.new
    threads = Array.new(8) do
      Thread.new do
        50.times do
          result = Emoji.find_by_alias("smile")
          unless result && result.name == "smile"
            mutex.synchronize { errors << "unexpected lookup: #{result.inspect}" }
          end
        end
      end
    end
    threads.each(&:join)
    assert_equal [], errors
  end

  test "concurrent create and remove does not corrupt the registry" do
    prefix = "concurrency_dogfood_"
    created = Mutex.new
    emojis = []
    errors = []

    threads = Array.new(4) do |i|
      Thread.new do
        name = "#{prefix}#{i}"
        emoji = Emoji.create(name)
        created.synchronize { emojis << emoji }
        20.times { Emoji.find_by_alias(name) }
      rescue => e
        created.synchronize { errors << "#{name}: #{e.class}: #{e.message}" }
      end
    end
    threads.each(&:join)

    assert_equal [], errors, errors.join("\n")
    emojis.each do |emoji|
      assert_equal emoji, Emoji.find_by_alias(emoji.name)
    end
  ensure
    emojis&.each { |emoji| Emoji.remove_emoji(emoji) }
  end
end