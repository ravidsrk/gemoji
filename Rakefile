require 'digest'
require 'rake/testtask'
require_relative 'db/unicode_versions'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/*_test.rb"]
end

def verify_unicode_emoji_test_checksum(path)
  actual = Digest::SHA256.file(path).hexdigest
  return if actual == UNICODE_EMOJI_TEST_SHA256

  abort "vendor/unicode-emoji-test.txt checksum mismatch: " \
        "expected #{UNICODE_EMOJI_TEST_SHA256}, got #{actual}"
end

namespace :db do
  desc %(Generate Emoji data files needed for development)
  task :generate => [
    'vendor/unicode-emoji-test.txt',
  ] do
    verify_unicode_emoji_test_checksum('vendor/unicode-emoji-test.txt')
  end

  desc %(Dump a list of supported Emoji with Unicode descriptions and aliases)
  task :dump => :generate do
    system 'ruby', '-Ilib', 'db/dump.rb'
  end
end

file 'vendor/unicode-emoji-test.txt' do |t|
  url = "https://unicode.org/Public/emoji/#{UNICODE_VERSION}/emoji-test.txt"
  system 'curl', '-fsSL', url, '-o', t.name
  verify_unicode_emoji_test_checksum(t.name)
end