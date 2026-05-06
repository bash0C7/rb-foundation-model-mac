# frozen_string_literal: true

module AppleFoundationModel
  class Session
    def initialize(instructions: nil)
      if (reason = AppleFoundationModel.send(:__availability_reason))
        raise UnavailableError, "Apple Intelligence unavailable: #{reason}"
      end
      @native = Native.new(instructions)
      @closed = false
    end

    def respond(to:)
      raise Error, "session is closed" if @closed
      @native.respond(to)
    end

    def stream_response(to:)
      raise Error, "session is closed" if @closed
      raise ArgumentError, "block required for stream_response" unless block_given?
      buf = String.new
      @native.stream(to) { |chunk| buf << chunk; yield chunk }
      buf
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end
end
