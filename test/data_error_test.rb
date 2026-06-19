require 'test_helper'
require 'tempfile'
require 'open3'

class DataErrorTest < TestCase
  test "raises DataError when emoji.json is not valid JSON" do
    lib_path = File.expand_path('../lib', __dir__)
    invalid = Tempfile.new(['emoji', '.json'])
    invalid.write("{not valid json")
    invalid.close

    script = Tempfile.new(['data_error', '.rb'])
    script.write(<<~RUBY)
      $LOAD_PATH.unshift #{lib_path.inspect}
      require 'emoji'

      Emoji.send(:remove_instance_variable, :@all) if Emoji.instance_variable_defined?(:@all)
      Emoji.send(:remove_instance_variable, :@names_index) if Emoji.instance_variable_defined?(:@names_index)
      Emoji.send(:remove_instance_variable, :@unicodes_index) if Emoji.instance_variable_defined?(:@unicodes_index)

      def Emoji.data_file
        #{invalid.path.inspect}
      end

      begin
        Emoji.all
      rescue Emoji::DataError => e
        puts e.message
        exit 0
      end
      warn "expected DataError"
      exit 1
    RUBY
    script.close

    stdout, stderr, status = Open3.capture3('ruby', script.path)
    assert status.success?, "subprocess failed (stderr: #{stderr})"
    assert_match(/Failed to parse/, stdout)
    assert_match(/emoji/, stdout)
  ensure
    invalid&.unlink
    script&.unlink
  end
end