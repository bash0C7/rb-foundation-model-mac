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
      response = +""
      @native.stream(to) { |chunk| response << chunk }
      response
    end

    def stream_response(to:, stop_at: nil)
      raise Error, "session is closed" if @closed
      raise ArgumentError, "block required for stream_response" unless block_given?
      response = +""
      @native.stream(to, stop_at: stop_at) do |chunk|
        response << chunk
        yield chunk
      end
      response
    end

    def cancel_stream
      @native.cancel_stream
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end
end
