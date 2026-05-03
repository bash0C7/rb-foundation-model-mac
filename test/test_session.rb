# frozen_string_literal: true
require "test_helper"

class TestSession < Test::Unit::TestCase
  def test_session_with_instructions_responds_to_prompt
    session = AppleFoundationModel::Session.new(
      instructions: "You answer in exactly one word."
    )
    response = session.respond(to: "What color is the sky?")
    assert_kind_of String, response
    assert response.length > 0
  end

  def test_session_without_instructions_works
    session = AppleFoundationModel::Session.new
    response = session.respond(to: "Say hi.")
    assert_kind_of String, response
    assert response.length > 0
  end

  def test_session_can_be_explicitly_closed
    session = AppleFoundationModel::Session.new
    session.respond(to: "Hello.")
    session.close
    assert_raise(AppleFoundationModel::Error) do
      session.respond(to: "Hello again.")
    end
  end
end
