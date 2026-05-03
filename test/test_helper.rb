# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"
require "test-unit"

# Skip integration tests if Ollama isn't reachable.
def ollama_running?
  require "net/http"
  uri = URI(ENV.fetch("OLLAMA_HOST", "http://localhost:11434"))
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 2
  res = http.get("/api/tags")
  res.is_a?(Net::HTTPSuccess)
rescue
  false
end
