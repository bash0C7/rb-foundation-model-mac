# rb-foundation-model-mac

On-device LLM inference for Ruby on macOS via [Ollama](https://ollama.ai).

The gem's API is named for Apple Foundation Models (which it will eventually support natively on macOS 26+). For now it routes to a local Ollama server, so it runs on any macOS version that can host Ollama.

## Requirements

- macOS (any version supported by Ollama)
- Ruby 3.2+
- A running Ollama server with at least one chat-capable model pulled

## Installation

Add to your Gemfile:

```ruby
gem "rb-foundation-model-mac"
```

Run a model in Ollama (any chat-capable model works; `gemma4:e2b` is the gem's default for fast iteration):

```bash
ollama pull gemma4:e2b
ollama serve  # if not already running
```

Configure host/model via environment variables if you don't want the defaults:

```bash
export OLLAMA_HOST=http://localhost:11434     # default
export OLLAMA_MODEL=gemma4:e2b                 # default
```

## Usage

### One-shot generation

```ruby
require "foundation_model_mac"

response = AppleFoundationModel.generate(
  prompt: "Name three programming languages.",
  instructions: "Reply with a comma-separated list."
)
puts response
```

### Multi-turn session

```ruby
session = AppleFoundationModel::Session.new(
  instructions: "You answer in one sentence."
)
puts session.respond(to: "What's a Ruby block?")
puts session.respond(to: "Give me one example.")  # remembers context
session.close
```

### Streaming

```ruby
session = AppleFoundationModel::Session.new
session.stream_response(to: "Tell me a fact.") do |chunk|
  print chunk
end
session.close
```

### Programmatic configuration

```ruby
AppleFoundationModel.configure do |c|
  c.instance_variable_set(:@host, "http://my-ollama:11434")
  c.instance_variable_set(:@default_model, "llama3.2:latest")
end
```

(or use `OLLAMA_HOST` / `OLLAMA_MODEL` env vars at process startup, which is the recommended path.)

## Roadmap

- Apple Foundation Models backend (macOS 26+) via Swift FFI — when Apple's API surface stabilizes and the dev machine can run macOS 26.
- Embeddings API (consumed by `rb-apple-sdk-knowledge`).
- Tool / function calling.

## License

MIT
