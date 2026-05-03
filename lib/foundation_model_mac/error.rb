# frozen_string_literal: true

module AppleFoundationModel
  class Error < StandardError; end
  class ConnectionError < Error; end
  class APIError < Error; end
end
