# frozen_string_literal: true

require_relative "foundation_model_mac/version"
require_relative "foundation_model_mac/foundation_model_mac"
require_relative "foundation_model_mac/session"

module AppleFoundationModel
  class Error < StandardError; end
end
