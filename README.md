# rb-foundation-model-mac

On-device LLM inference for Ruby on macOS via the native [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) framework (Apple Intelligence).

## Requirements

- macOS 26+ (Tahoe / later)
- Apple Silicon
- Apple Intelligence enabled with the on-device model fully downloaded (Settings → Apple Intelligence & Siri)
- Ruby 3.2+
- Swift 6.3+ (recommended installer: [`swiftly`](https://www.swift.org/install/macos/))

## Installation

`Gemfile`:

```ruby
gem "rb-foundation-model-mac"
```

```bash
bundle install
```

The Swift native extension is built via `swift build` at install time. Xcode is not required.

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

## Examples

The `examples/` directory contains runnable sample code.

### English Examples

**One-shot generation:**
```bash
bundle exec ruby examples/basic_generation.rb
```

**Multi-turn session (context aware):**
```bash
bundle exec ruby examples/multi_turn.rb
```

**Streaming response:**
```bash
bundle exec ruby examples/streaming.rb
```

### 日本語サンプル

**シンプル版（引数で質問を指定）:**
```bash
bundle exec ruby examples/japanese_simple.rb "あなたの質問"
```
デフォルト: `"Rubyについて短く説明してください。"`

**マルチプロンプト版（複数の質問を処理）:**
```bash
bundle exec ruby examples/japanese_session.rb "質問1" "質問2" "質問3"
```

**ストリーミング版（リアルタイム出力）:**
```bash
bundle exec ruby examples/japanese_streaming.rb "あなたの質問"
```
デフォルト: `"人工知能についてについて、詳しく説明してください。"`

## Errors

- `AppleFoundationModel::UnavailableError` — Apple Intelligence is not available (unsupported macOS version, unsupported hardware, user has not enabled it, model not yet downloaded, etc.). Raised from `Session.new` with the reason included.
- `AppleFoundationModel::GenerationError` — error during Apple FM inference (context overflow, guardrail violation, etc.).
- `AppleFoundationModel::Error` — parent of the above, plus other Ruby-side errors such as operating on a closed Session.

## Roadmap

- Embeddings API (consumed by `rb-apple-sdk-knowledge`)
- Tool / function calling
- Cancellation support (the Apple FM Task cancellation path is not currently bridged to Ruby)

## Migration

### Breaking (v0.x → v0.y)

- Swift / C-ABI `fmm_stream_start` gained two new parameters: `stop_strings: UnsafePointer<UnsafePointer<CChar>?>?` and `stop_count: Int32`. Existing native callers (other than this gem's own C bridge) must pass `nil, 0` to retain old behaviour.
- Ruby callers are unaffected — the Ruby `Native#stream` method accepts the new `stop_at:` kwarg, and `Session#stream_response` exposes it; the old positional-only call (`session.stream_response(to: "...") { |c| ... }`) continues to work unchanged.

### Added

- `Session#stream_response(to:, stop_at: [String])` — stop streaming when cumulative output contains any of the given strings (Swift-side check, low-latency).
- `Session#cancel_stream` — abort an in-flight stream from outside the block (useful for client-side parsers that detect completion).

## License

MIT
