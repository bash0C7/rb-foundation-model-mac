# rb-foundation-model-mac

On-device LLM inference for Ruby on macOS via the native [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) framework (Apple Intelligence).

## Requirements

- macOS 26+ (Tahoe / 後継)
- Apple Silicon
- Apple Intelligence が有効化されてオンデバイスモデルが download 完了済み (Settings → Apple Intelligence & Siri)
- Ruby 3.2+
- Swift 6.3+ (推奨インストーラ: [`swiftly`](https://www.swift.org/install/macos/))

## Installation

`Gemfile`:

```ruby
gem "rb-foundation-model-mac"
```

```bash
bundle install
```

ビルド時に Swift native extension が `swift build` 経由で組まれる。Xcode は不要。

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

`examples/` ディレクトリに実行可能なサンプルコードが含まれています。

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

- `AppleFoundationModel::UnavailableError` — Apple Intelligence が利用できない（macOS バージョン不足、ハードウェア未対応、ユーザーが未有効化、モデル未 download など）。`Session.new` 時に reason を含めて raise。
- `AppleFoundationModel::GenerationError` — Apple FM の推論中エラー（context overflow / guardrail violation など）。
- `AppleFoundationModel::Error` — 上記の親、および closed Session への操作などその他の Ruby 側エラー。

## Roadmap

- Embeddings API（`rb-apple-sdk-knowledge` で消費）
- Tool / function calling
- Cancellation サポート（現在は Apple FM Task のキャンセル経路を Ruby に橋渡ししていない）

## License

MIT
