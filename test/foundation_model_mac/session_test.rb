# frozen_string_literal: true

require "test_helper"

class TestSession < Test::Unit::TestCase
  def setup
    reason = apple_foundation_model_unavailable_reason
    omit reason if reason
  end

  def test_session_with_instructions_responds
    session = AppleFoundationModel::Session.new(
      instructions: "You answer in exactly one word."
    )
    response = session.respond(to: "What color is the sky?")
    assert_kind_of String, response
    assert response.length > 0
    session.close
  end

  def test_session_without_instructions
    session = AppleFoundationModel::Session.new
    response = session.respond(to: "Say hi.")
    assert_kind_of String, response
    assert response.length > 0
    session.close
  end

  def test_session_remembers_context_across_turns
    session = AppleFoundationModel::Session.new(
      instructions: "Refer back to what the user just said. Be concise."
    )
    session.respond(to: "My name is Alice.")
    response = session.respond(to: "What is my name?")
    assert_match(/alice/i, response,
                  "session should remember 'Alice' across turns; got: #{response.inspect}")
    session.close
  end

  def test_interrupt_stops_respond_without_waiting_for_the_response
    session = AppleFoundationModel::Session.new
    main = Thread.current
    interrupted_at = nil
    Thread.new do
      sleep 0.5
      interrupted_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      main.raise(Interrupt)
    end
    assert_raise(Interrupt) do
      session.respond(to: slow_to_start_prompt)
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - interrupted_at, :<, 3
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_generation_error_leaves_the_session_usable
    session = AppleFoundationModel::Session.new(instructions: "Reply briefly.")
    assert_raise(AppleFoundationModel::GenerationError) do
      session.respond(to: "apple " * 6000)
    end
    assert_kind_of String, session.respond(to: "Say hi.")
    session.close
  end

  def test_session_explicit_close_blocks_further_use
    session = AppleFoundationModel::Session.new
    session.respond(to: "Hello.")
    session.close
    assert_raise(AppleFoundationModel::Error) do
      session.respond(to: "Hello again.")
    end
  end
end
