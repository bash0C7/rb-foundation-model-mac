# frozen_string_literal: true

require "test_helper"

class FoundationModelMacSampleTest < Test::Unit::TestCase
  test "perform echoes input from skeleton implementation" do
    assert_equal("hello", FoundationModelMac.perform("hello"))
    # TODO: Replace with a meaningful assertion once you implement perform.
  end
end
