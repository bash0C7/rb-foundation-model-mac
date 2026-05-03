# frozen_string_literal: true

require_relative "foundation_model_mac/version"
require_relative "foundation_model_mac/error"
require_relative "foundation_model_mac/client"
require_relative "foundation_model_mac/session"

module AppleFoundationModel
  class << self
    def configure
      yield default_client if block_given?
      default_client
    end

    def default_client
      @default_client ||= Client.new
    end

    def generate(prompt:, instructions: nil, model: nil)
      default_client.generate(
        prompt: prompt,
        system: instructions,
        model: model
      )
    end
  end
end
