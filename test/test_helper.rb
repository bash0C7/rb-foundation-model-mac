# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

require "test-unit"

def slow_to_start_prompt
  (1..300).map { |i| "Station #{i} records a calm sea and a light breeze." }.join(" ") +
    " Write a long story about these stations."
end

def apple_foundation_model_unavailable_reason
  AppleFoundationModel::Session.new.close
  nil
rescue AppleFoundationModel::UnavailableError => e
  e.message
end
