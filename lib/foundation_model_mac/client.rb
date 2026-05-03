# frozen_string_literal: true
require "net/http"
require "json"
require "uri"

module AppleFoundationModel
  class Client
    DEFAULT_HOST = "http://localhost:11434"
    DEFAULT_MODEL = "gemma4:e2b"

    attr_reader :host, :default_model

    def initialize(host: nil, default_model: nil)
      @host = host || ENV["OLLAMA_HOST"] || DEFAULT_HOST
      @default_model = default_model || ENV["OLLAMA_MODEL"] || DEFAULT_MODEL
    end

    def chat(messages:, model: nil, stream: false, &block)
      model ||= @default_model
      payload = { model: model, messages: messages, stream: stream }
      if stream
        raise ArgumentError, "block required when stream: true" unless block_given?
        post_streaming("/api/chat", payload, &block)
      else
        json = post_json("/api/chat", payload)
        json.dig("message", "content").to_s
      end
    end

    def generate(prompt:, system: nil, model: nil, stream: false, &block)
      model ||= @default_model
      payload = { model: model, prompt: prompt, stream: stream }
      payload[:system] = system if system && !system.empty?
      if stream
        raise ArgumentError, "block required when stream: true" unless block_given?
        post_streaming("/api/generate", payload) do |chunk_obj|
          block.call(chunk_obj["response"].to_s) if chunk_obj["response"]
        end
      else
        json = post_json("/api/generate", payload)
        json["response"].to_s
      end
    end

    private

    def post_json(path, payload)
      uri = URI(@host + path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 300
      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      res = http.request(req)
      raise APIError, "Ollama returned #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
      JSON.parse(res.body)
    rescue Errno::ECONNREFUSED, SocketError => e
      raise ConnectionError, "could not reach Ollama at #{@host}: #{e.message}"
    end

    def post_streaming(path, payload, &block)
      uri = URI(@host + path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 300
      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      http.request(req) do |res|
        unless res.is_a?(Net::HTTPSuccess)
          body = res.read_body
          raise APIError, "Ollama returned #{res.code}: #{body}"
        end
        buffer = String.new
        res.read_body do |segment|
          buffer << segment
          while (idx = buffer.index("\n"))
            line = buffer.slice!(0, idx + 1).chomp
            next if line.empty?
            chunk = JSON.parse(line)
            if path == "/api/chat"
              text = chunk.dig("message", "content").to_s
              block.call(text) unless text.empty?
            else
              block.call(chunk)
            end
            return if chunk["done"]
          end
        end
      end
    rescue Errno::ECONNREFUSED, SocketError => e
      raise ConnectionError, "could not reach Ollama at #{@host}: #{e.message}"
    end
  end
end
