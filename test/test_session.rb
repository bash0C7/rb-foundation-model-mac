# frozen_string_literal: true
require "test_helper"

class TestSession < Test::Unit::TestCase
  def setup
    omit "Apple Intelligence unavailable: #{apple_foundation_model_unavailable_reason}" \
      unless apple_foundation_model_available?
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

  def test_session_explicit_close_blocks_further_use
    session = AppleFoundationModel::Session.new
    session.respond(to: "Hello.")
    session.close
    assert_raise(AppleFoundationModel::Error) do
      session.respond(to: "Hello again.")
    end
  end
end
