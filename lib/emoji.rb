# encoding: utf-8
# frozen_string_literal: true

require 'emoji/unicode'
require 'emoji/character'
require 'json'

module Emoji
  extend self

  class DuplicateAliasError < StandardError; end
  class DataError < StandardError; end

  @registry_mutex = Mutex.new

  def data_file
    File.expand_path('../../db/emoji.json', __FILE__)
  end

  # The emoji catalog and alias/unicode indices are loaded on first use (see
  # ensure_loaded) and kept in memory for the process lifetime. Callers that
  # only need a few lookups still pay the full-catalog memory cost once loaded.
  def all
    ensure_loaded
    @all.dup.freeze
  end

  def preload!
    ensure_loaded
    self
  end

  # Public: Initialize an Emoji::Character instance and yield it to the block.
  # The character is added to the `Emoji.all` set.
  def create(name)
    emoji = Emoji::Character.new(name)
    registry_synchronize do
      ensure_loaded
      @all << edit_emoji_unsafe(emoji) { yield emoji if block_given? }
    end
    emoji
  end

  # Public: Remove an emoji from the registry and its index entries.
  def remove_emoji(emoji)
    registry_synchronize do
      remove_emoji_unsafe(emoji)
    end
  end

  # Public: Yield an emoji to the block and update the indices in case its
  # aliases or unicode_aliases lists changed.
  def edit_emoji(emoji)
    registry_synchronize do
      edit_emoji_unsafe(emoji) { yield emoji if block_given? }
    end
  end

  # Public: Find an emoji by its aliased name. Return nil if missing.
  def find_by_alias(name)
    names_index[name]
  end

  # Public: Find an emoji by its unicode character. Return nil if missing.
  def find_by_unicode(unicode)
    unicodes_index[unicode] || unicodes_index[unicode.gsub(SKIN_TONE_RE, "")]
  end

  private
    def registry_synchronize
      if Thread.current[:emoji_registry_lock]
        yield
      else
        @registry_mutex.synchronize do
          Thread.current[:emoji_registry_lock] = true
          begin
            yield
          ensure
            Thread.current[:emoji_registry_lock] = false
          end
        end
      end
    end

    def ensure_loaded
      return if defined? @all
      registry_synchronize do
        unless defined? @all
          @all = []
          parse_data_file
        end
      end
    end

    def edit_emoji_unsafe(emoji)
      @names_index ||= Hash.new
      @unicodes_index ||= Hash.new

      @names_index.delete_if { |_, value| value == emoji }
      @unicodes_index.delete_if { |_, value| value == emoji }

      yield emoji

      emoji.aliases.each do |name|
        existing = @names_index[name]
        if existing && existing != emoji
          raise DuplicateAliasError,
            "alias #{name.inspect} is already used by #{existing.name.inspect}"
        end
        @names_index[name] = emoji
      end
      emoji.unicode_aliases.each do |unicode|
        @unicodes_index[unicode] = emoji
      end

      emoji
    end

    def remove_emoji_unsafe(emoji)
      @names_index ||= Hash.new
      @unicodes_index ||= Hash.new

      @names_index.delete_if { |_, value| value == emoji }
      @unicodes_index.delete_if { |_, value| value == emoji }

      if defined?(@all) && @all
        @all.delete(emoji)
      end

      emoji
    end

    def parse_data_file
      data = begin
        File.open(data_file, 'r:UTF-8') do |file|
          JSON.parse(file.read, symbolize_names: true)
        end
      rescue JSON::ParserError => e
        raise DataError, "Failed to parse #{data_file}: #{e.message}"
      end

      if "".respond_to?(:-@)
        # Ruby >= 2.3 this is equivalent to .freeze
        # Ruby >= 2.5 this will freeze and dedup
        dedup = lambda { |str| -str }
      else
        dedup = lambda { |str| str.freeze }
      end

      append_unicode = lambda do |emoji, raw|
        unless TEXT_GLYPHS.include?(raw) || emoji.unicode_aliases.include?(raw)
          emoji.add_unicode_alias(dedup.call(raw))
        end
      end

      data.each do |raw_emoji|
        self.create(nil) do |emoji|
          raw_emoji.fetch(:aliases).each { |name| emoji.add_alias(dedup.call(name)) }
          if raw = raw_emoji[:emoji]
            append_unicode.call(emoji, raw)
            start_pos = 0
            while found_index = raw.index(VARIATION_SELECTOR_16, start_pos)
              # register every variant where one VARIATION_SELECTOR_16 is removed
              raw_alternate = raw.dup
              raw_alternate[found_index] = ""
              append_unicode.call(emoji, raw_alternate)
              start_pos = found_index + 1
            end
            if start_pos > 0
              # register a variant with all VARIATION_SELECTOR_16 removed
              append_unicode.call(emoji, raw.gsub(VARIATION_SELECTOR_16, ""))
            else
              # register a variant where VARIATION_SELECTOR_16 is added
              append_unicode.call(emoji, "#{raw}#{VARIATION_SELECTOR_16}")
            end
          end
          raw_emoji.fetch(:tags).each { |tag| emoji.add_tag(dedup.call(tag)) }

          emoji.category = dedup.call(raw_emoji.fetch(:category))
          emoji.description = dedup.call(raw_emoji.fetch(:description))
          emoji.unicode_version = dedup.call(raw_emoji.fetch(:unicode_version))
          emoji.ios_version = dedup.call(raw_emoji.fetch(:ios_version))
          emoji.skin_tones = raw_emoji.fetch(:skin_tones, false)
        end
      end
    end

    def names_index
      ensure_loaded
      @names_index
    end

    def unicodes_index
      ensure_loaded
      @unicodes_index
    end
end
