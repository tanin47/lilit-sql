# frozen_string_literal: true

require 'minitest/autorun'

module Minitest
  class Spec
    def assert_content_equal(expected, actual, message = nil)
      assert_equal(strip_whitespaces(expected), strip_whitespaces(actual), message)
    end

    private

    def strip_whitespaces(content)
      content.gsub(/\s+/, ' ').strip
    end
  end
end
