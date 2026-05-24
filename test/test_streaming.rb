# frozen_string_literal: true
require "test_helper"

class TestStreaming < Test::Unit::TestCase
  def setup
    omit "Apple Intelligence unavailable: #{apple_foundation_model_unavailable_reason}" \
      unless apple_foundation_model_available?
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

  def test_stream_response_accepts_stop_at_kwarg
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with the words 'apple banana cherry'."
    )
    chunks = []
    session.stream_response(
      to: "Just say the words.",
      stop_at: ["cherry"],
    ) do |chunk|
      chunks << chunk
    end
    full = chunks.join
    # stop_at terminates early once cumulative output contains "cherry"
    assert full.length > 0, "expected at least one chunk"
    session.close
  end

  def test_cancel_stream_terminates_iteration
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with at least ten words."
    )
    chunks = []
    session.stream_response(to: "Name ten primary colors.") do |chunk|
      chunks << chunk
      session.cancel_stream if chunks.length >= 1
    end
    assert chunks.length < 50, "cancel_stream should terminate the loop quickly"
    session.close
  end

  def test_block_break_does_not_leak_stream
    session = AppleFoundationModel::Session.new(instructions: "Reply briefly.")
    begin
      session.stream_response(to: "Say hi.") do |_chunk|
        break
      end
      # rb_protect caught the break: @__active_stream must be cleared (not a leaked pointer)
      assert_nil session.instance_variable_get(:@__active_stream)
    ensure
      session.close
    end
  end
end
