# frozen_string_literal: true

require "test_helper"

class TestStreaming < Test::Unit::TestCase
  def setup
    reason = apple_foundation_model_unavailable_reason
    omit reason if reason
  end

  def test_stream_response_yields_multiple_chunks
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with at least three short words."
    )
    chunks = []
    result = session.stream_response(to: "Name three primary colors.") do |chunk|
      chunks << chunk
    end
    assert chunks.length > 1, "expected several streamed chunks, got: #{chunks.inspect}"
    assert_equal chunks.join, result
    assert_equal Encoding::UTF_8, result.encoding
    session.close
  end

  def test_stream_response_requires_block
    session = AppleFoundationModel::Session.new
    assert_raise(ArgumentError) do
      session.stream_response(to: "Hello")
    end
    session.close
  end

  def test_stop_at_ends_with_the_chunk_that_completes_the_stop_string
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with at least ten words."
    )
    chunks = []
    result = session.stream_response(to: "Name ten animals.", stop_at: [" "]) do |chunk|
      chunks << chunk
    end
    assert_include result, " "
    assert_not_include result[0, result.length - chunks.last.length], " "
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_cancel_stream_terminates_iteration
    session = AppleFoundationModel::Session.new(
      instructions: "Reply with at least ten words."
    )
    chunks = []
    session.stream_response(to: "Name ten primary colors.") do |chunk|
      chunks << chunk
      session.cancel_stream
    end
    assert_equal 1, chunks.length
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_block_break_stops_generation_before_returning
    session = AppleFoundationModel::Session.new(instructions: "Reply with at least ten words.")
    session.stream_response(to: "Name ten animals.") do |_chunk|
      break
    end
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_generation_error_leaves_the_session_usable
    session = AppleFoundationModel::Session.new(instructions: "Reply briefly.")
    assert_raise(AppleFoundationModel::GenerationError) do
      session.stream_response(to: "apple " * 6000) { |_chunk| }
    end
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_kill_before_the_first_chunk_stops_generation
    session = AppleFoundationModel::Session.new
    thread = Thread.new { session.stream_response(to: slow_to_start_prompt) { |_chunk| } }
    sleep 0.2
    killed_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    thread.kill
    thread.join
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - killed_at, :<, 3
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_multibyte_chunks_are_valid_utf8
    session = AppleFoundationModel::Session.new(instructions: "日本語で答え、各文の後に絵文字を一つ付けてください。")
    chunks = []
    session.stream_response(to: "猫について三文で説明してください。") { |chunk| chunks << chunk }
    assert_match(/\p{Han}|\p{Hiragana}/, chunks.join)
    chunks.each do |chunk|
      assert_equal Encoding::UTF_8, chunk.encoding
      assert chunk.valid_encoding?, "invalid chunk: #{chunk.b.inspect}"
    end
    session.close
  end

  def test_stopped_turn_stays_in_history
    session = AppleFoundationModel::Session.new(instructions: "Answer briefly.")
    session.stream_response(
      to: "My favorite fruit is banana. Count from 1 to 20, one number per line.",
      stop_at: ["3"]
    ) { |_chunk| }
    assert_match(/banana/i, session.respond(to: "What is my favorite fruit?"))
    session.close
  end

  def test_failed_turn_leaves_no_trace_in_history
    session = AppleFoundationModel::Session.new(instructions: "Answer briefly.")
    assert_raise(AppleFoundationModel::GenerationError) do
      session.stream_response(to: "My favorite fruit is cherry. " + "apple " * 6000) { |_chunk| }
    end
    assert_not_match(/cherry/i, session.respond(to: "What is my favorite fruit?"))
    session.close
  end

  def test_block_exception_propagates_and_stops_generation
    session = AppleFoundationModel::Session.new(instructions: "Reply with at least ten words.")
    assert_raise(RuntimeError) do
      session.stream_response(to: "Name ten animals.") { |_chunk| raise "stop" }
    end
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end
end
