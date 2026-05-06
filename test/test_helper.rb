# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"
require "test-unit"

def apple_foundation_model_available?
  AppleFoundationModel::Session.new.close
  true
rescue AppleFoundationModel::UnavailableError
  false
end

def apple_foundation_model_unavailable_reason
  AppleFoundationModel::Session.new.close
  nil
rescue AppleFoundationModel::UnavailableError => e
  e.message
end
