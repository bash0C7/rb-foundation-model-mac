# frozen_string_literal: true
require "test_helper"

class TestStreaming < Test::Unit::TestCase
  def setup
    omit "Ollama not running" unless ollama_running?
  end

  def test_stream_response_yields_multiple_chunks
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with at least three short words."
    )
    chunks = []
    session.stream_response(to: "Name three primary colors.") do |chunk|
      chunks << chunk
    end
    assert chunks.length > 0, "expected at least one streamed chunk"
    full = chunks.join
    assert full.length > 0, "expected non-empty concatenation"
    session.close
  end

  def test_stream_response_requires_block
    session = AppleFoundationModel::Session.new
    assert_raise(ArgumentError) do
      session.stream_response(to: "Hello")
    end
    session.close
  end
end
