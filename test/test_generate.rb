# frozen_string_literal: true
require "test_helper"

class TestGenerate < Test::Unit::TestCase
  def setup
    omit "Ollama not running on #{ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')}" unless ollama_running?
  end

  def test_generate_returns_non_empty_string
    response = AppleFoundationModel.generate(prompt: "Say hello in one word.")
    assert_kind_of String, response
    assert response.length > 0, "expected non-empty response, got: #{response.inspect}"
  end

  def test_generate_with_instructions
    response = AppleFoundationModel.generate(
      prompt: "What color is grass?",
      instructions: "Reply with exactly one word, lowercase, no punctuation."
    )
    assert_kind_of String, response
    assert response.length > 0
  end

  def test_generate_uses_configured_model
    response = AppleFoundationModel.generate(
      prompt: "Hi",
      model: ENV.fetch("OLLAMA_MODEL", "gemma4:e2b")
    )
    assert_kind_of String, response
    assert response.length > 0
  end
end
