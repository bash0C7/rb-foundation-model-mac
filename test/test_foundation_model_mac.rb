# frozen_string_literal: true
require "test_helper"

class TestAppleFoundationModel < Test::Unit::TestCase
  def test_generate_returns_non_empty_string_for_simple_prompt
    response = AppleFoundationModel.generate(prompt: "Say hello in one word.")
    assert_kind_of String, response
    assert response.length > 0, "expected non-empty response, got: #{response.inspect}"
  end
end
