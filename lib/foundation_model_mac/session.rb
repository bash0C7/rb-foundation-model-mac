# frozen_string_literal: true

module AppleFoundationModel
  class Session
    def initialize(instructions: nil, model: nil, client: nil)
      @client = client || Client.new(default_model: model)
      @model = model
      @messages = []
      @messages << { role: "system", content: instructions } if instructions && !instructions.empty?
      @closed = false
    end

    def respond(to:)
      raise Error, "session is closed" if @closed
      @messages << { role: "user", content: to }
      reply = @client.chat(messages: @messages, model: @model)
      @messages << { role: "assistant", content: reply }
      reply
    end

    def stream_response(to:)
      raise Error, "session is closed" if @closed
      raise ArgumentError, "block required for stream_response" unless block_given?
      @messages << { role: "user", content: to }
      buffer = String.new
      @client.chat(messages: @messages, model: @model, stream: true) do |chunk|
        buffer << chunk
        yield chunk
      end
      @messages << { role: "assistant", content: buffer }
      buffer
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end
end
