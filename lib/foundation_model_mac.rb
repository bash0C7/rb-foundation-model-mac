# frozen_string_literal: true

require_relative "foundation_model_mac/version"

module AppleFoundationModel
  class Error            < StandardError; end
  class UnavailableError < Error; end
  class GenerationError  < Error; end
end

require_relative "foundation_model_mac/foundation_model_mac"
require_relative "foundation_model_mac/session"

module AppleFoundationModel
  def self.generate(prompt:, instructions: nil)
    s = Session.new(instructions: instructions)
    begin
      s.respond(to: prompt)
    ensure
      s.close
    end
  end

  private_class_method :__availability_reason
  private_constant :Native
end
