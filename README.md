# rb-foundation-model-mac

Ruby binding for Apple's on-device [Foundation Models](https://developer.apple.com/documentation/foundationmodels) framework (Apple Intelligence) on macOS / Apple Silicon. Calls `LanguageModelSession` on the default `SystemLanguageModel` from Ruby via Swift Package Manager and a thin C bridge. Built on [swift_gem](https://github.com/bash0C7/swift_gem).

## Requirements

- macOS 27+, Apple Silicon
- Apple Intelligence enabled with the on-device model downloaded (System Settings → Apple Intelligence & Siri)
- Xcode 27 (builds run `xcrun swift`)
- Ruby 4.0+, Bundler 4.x

## Installation

Install from source:

```bash
git clone https://github.com/bash0C7/rb-foundation-model-mac.git
cd rb-foundation-model-mac
bundle install
bundle exec rake compile
```

## Usage

### One-shot generation

```ruby
require "foundation_model_mac"

AppleFoundationModel.generate(
  prompt: "Name three programming languages.",
  instructions: "Reply with a comma-separated list."
)
# => "Python, JavaScript, Java"
```

### Multi-turn session

A `Session` keeps the conversation, so each prompt sees the earlier turns.

```ruby
session = AppleFoundationModel::Session.new(instructions: "You answer in one sentence.")
session.respond(to: "My name is Alice.")
session.respond(to: "What is my name?")
# => "Your name is Alice."
session.close
```

### Streaming

`stream_response` yields the response in incremental chunks as the model generates it and returns the concatenated text.

```ruby
session = AppleFoundationModel::Session.new
session.stream_response(to: "Tell me a fact.") do |chunk|
  print chunk
end
session.close
```

Generation stops early in three ways:

- `stop_at:` takes an array of strings. Generation stops as soon as the response contains any of them; the chunk that completes the stop string is the last one yielded.
- `session.cancel_stream`, called inside the block, stops generation. No further chunks are yielded.
- Leaving the block with `break` or an exception stops generation.

The following call returns the text up to and including the first chunk that contains `"5"`. A chunk can hold several characters, so the text can run past the `5`.

```ruby
session.stream_response(to: "Count from 1 to 20, one number per line.", stop_at: ["5"]) { |chunk| }
```

`Interrupt` (Ctrl-C), `Thread#raise`, and `Thread#kill` stop generation in both `respond` and `stream_response`.

`respond` and `stream_response` return once the model has stopped, so the session accepts the next prompt right away. A stopped response stays in the session's history with all the text the model generated before it stopped, which can be longer than the text yielded to the block. The next prompt sees that unfinished response, and the model may continue it: after a story is stopped halfway, `"Say hi."` can get the rest of the story. A request that fails with `GenerationError` leaves no trace in the history.

Open an IRB console with the gem preloaded:

```bash
bundle exec rake console
```

## Errors

- `AppleFoundationModel::UnavailableError`: raised by `Session.new` and `generate` when the on-device model is unavailable. The message carries the reason: `deviceNotEligible`, `appleIntelligenceNotEnabled`, or `modelNotReady`.
- `AppleFoundationModel::GenerationError`: raised when generation fails, for example on a guardrail violation or when the context window is exceeded. The session stays usable.
- `AppleFoundationModel::Error`: the parent of both, also raised by `respond` and `stream_response` on a closed session.

## Reference: Ruby examples

```bash
bundle exec rake compile
bundle exec ruby examples/basic_generation.rb
bundle exec ruby examples/multi_turn.rb
bundle exec ruby examples/streaming.rb
bundle exec ruby examples/japanese_simple.rb "Rubyについて短く説明してください。"
bundle exec ruby examples/japanese_session.rb "macOSとは何ですか？" "これまでの説明をまとめてください。"
bundle exec ruby examples/japanese_streaming.rb "人工知能について、詳しく説明してください。"
```

The Japanese examples fall back to built-in prompts when called without arguments.

## Reference: pure Swift sample

`examples/foundation_model_mac.swift` streams a response without Ruby:

```bash
xcrun swift examples/foundation_model_mac.swift "Tell me a fact."
```

## Development

```bash
bundle install
bundle exec rake test
```

`rake test` validates `sig/foundation_model_mac.rbs`, runs `xcrun swift build -c release --package-path ext/foundation_model_mac`, builds the C extension into `lib/foundation_model_mac/foundation_model_mac.bundle`, then runs the tests. The tests call the on-device model and are omitted when it is unavailable. `bundle exec rake compile` runs only the build.

## License

MIT.
