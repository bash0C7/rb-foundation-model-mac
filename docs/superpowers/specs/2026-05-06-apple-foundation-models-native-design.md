# 2026-05-06 — Apple Foundation Models Native Backend (Ollama 完全削除)

## 背景と動機

`rb-foundation-model-mac` は Ruby 向け on-device LLM inference gem で、公開 API (`AppleFoundationModel.generate`, `Session#respond(to:)`, `Session#stream_response(to:)`) は当初から Apple Foundation Models フレームワークの API サーフェスをミラーする形で設計されていた。これまでは過渡的バックエンドとしてローカル Ollama サーバへ HTTP 経由で委譲していたが、開発機が macOS 26 にアップグレードされたため、当初の roadmap 通り **Apple Foundation Models フレームワークへネイティブ直結** に切り替える。

- **Ollama 関連コードはコミット時点で完全削除**する（後方互換 shim や fallback は一切残さない）。
- **公開 Ruby API は完全維持**する（`generate / Session.new / respond / stream_response / close / closed?`）。当初の README で約束した「ネイティブに切り替わっても API は変わらない」を履行する。
- 内部実装は最小限に保つ（**シンプル追求**）。`Client` クラス、`configure` ブロック、`default_client` シングルトン、`model:` キーワード、`OLLAMA_*` 環境変数などはすべて廃止。

## 範囲

- リポジトリ: `rb-foundation-model-mac`
- 対象: gem 内のすべての Ruby / 拡張ソース、テスト、example、README
- スコープ外: `swift_gem` への変更（`SwiftGem::Mkmf.create_swift_makefile` を消費するのみで、公開 API には触れない）。リリース手順、CI 設定、`rb-apple-sdk-knowledge` 等下流 gem への波及。

## 確定事項（ブレインストームでの決定）

| Q | 決定 |
|---|---|
| 公開 Ruby API の形 | **完全維持**（既存の名前空間・メソッド形をそのまま温存）|
| ストリーミング | **真のストリーミング**。Apple FM の `streamResponse(to:)` の `AsyncSequence` を Swift 側で `for try await` ループで回しながら、各 partial を C 関数ポインタ経由で Ruby block に逐次 yield |
| `model:` キーワード引数 | **完全削除**（`generate` / `Session.new` 両方）|
| `OLLAMA_HOST` / `OLLAMA_MODEL` 環境変数 | **完全削除** |
| 可用性チェック | **fail-fast**。`Session.new` の中で `SystemLanguageModel.default.availability` を見て `.unavailable` なら `UnavailableError` を即 raise（reason メッセージ含む）|
| エラー階層 | 抜本見直し。`Error / UnavailableError / GenerationError` の 3 種だけ。`ConnectionError` / `APIError` は削除 |
| 内部構造 | `Client` / `configure` / `default_client` を **完全削除**（残し禁止）|
| `swift_gem` の公開 API 互換性 | **完全互換維持** — `SwiftGem::Mkmf.create_swift_makefile` を呼ぶだけ。Generator・テンプレートは触らない |
| Streaming の chunk 意味論 | Apple FM の partial は cumulative。**Swift 層で diff を切り出して incremental** chunk として callback に渡す（既存テスト `chunks.join` 前提と整合）|

## アーキテクチャ層

```
┌─────────────────────────────────────────────────────────────┐
│ Ruby app (consumer)                                         │
│   AppleFoundationModel.generate / Session#respond(to:)      │
│   Session#stream_response(to:) { |chunk| ... } / #close     │
└────────────────────────┬────────────────────────────────────┘
                         │ pure-Ruby method calls
┌────────────────────────▼────────────────────────────────────┐
│ lib/foundation_model_mac/                                   │
│   foundation_model_mac.rb : module top + .generate +        │
│                             Error / UnavailableError /      │
│                             GenerationError 階層             │
│   session.rb              : Session class (FFI 直叩き)        │
│   version.rb                                                 │
└────────────────────────┬────────────────────────────────────┘
                         │ require "foundation_model_mac/foundation_model_mac"
┌────────────────────────▼────────────────────────────────────┐
│ ext/foundation_model_mac/foundation_model_mac.c             │
│   Init_foundation_model_mac:                                 │
│     rb_define_class("AppleFoundationModel::__Native")       │
│     TypedData_Wrap_Struct で opaque pointer                  │
│   rb_fmm_*  : Swift @c シンボル呼ぶ + rb_yield               │
└────────────────────────┬────────────────────────────────────┘
                         │ C ABI (SE-0495 @c, *-Swift.h)
┌────────────────────────▼────────────────────────────────────┐
│ ext/foundation_model_mac/Sources/FoundationModelMac/         │
│   FoundationModelMac.swift                                   │
│     class FMMSession (LanguageModelSession を保持)           │
│     @c 関数群 (FFI 境界)                                     │
└────────────────────────┬────────────────────────────────────┘
                         │ Swift import
┌────────────────────────▼────────────────────────────────────┐
│ Apple FoundationModels framework (macOS 26+, ネイティブ)      │
│   SystemLanguageModel.default                                │
│   LanguageModelSession.respond(to:) async throws             │
│   LanguageModelSession.streamResponse(to:) -> ResponseStream │
└─────────────────────────────────────────────────────────────┘
```

### 層の責務

- **Ruby 層** — 公開 API の形、引数バリデーション、エラークラス階層、close 状態管理。Apple FM のことは知らない。
- **C bridge** — opaque pointer ↔ Ruby object の往復、Swift `@c` シンボルへの delegate、`rb_yield` による block dispatch、Ruby GC 連動 (`TypedData_Wrap_Struct` の free function)。Apple FM API は呼ばない。
- **Swift Logic + Bridge (1 ファイル)** — `FMMSession` class が `LanguageModelSession` を保持。`@c` 関数が C ABI に export。async/sync 橋渡し（`DispatchSemaphore` で `Task { try await ... }` を同期化）。Apple FM 由来エラーを文字列化して error_out へ。
- **swift_gem** — `SwiftGem::Mkmf.create_swift_makefile` を `extconf.rb` から呼ぶだけ。**変更ゼロ**。

## ファイル構成（最終形）

```
lib/foundation_model_mac.rb
lib/foundation_model_mac/
  version.rb
  session.rb
ext/foundation_model_mac/
  extconf.rb
  foundation_model_mac.c
  Package.swift
  Sources/FoundationModelMac/
    FoundationModelMac.swift
test/
  test_helper.rb
  test_generate.rb
  test_session.rb
  test_streaming.rb
examples/
  basic_generation.rb
  multi_turn.rb
  streaming.rb
docs/superpowers/specs/
  2026-05-06-apple-foundation-models-native-design.md
```

## 公開 Ruby API（完全形）

### モジュールトップ

```ruby
module AppleFoundationModel
  class Error            < StandardError; end
  class UnavailableError < Error; end
  class GenerationError  < Error; end

  def self.generate(prompt:, instructions: nil)
    s = Session.new(instructions: instructions)
    begin
      s.respond(to: prompt)
    ensure
      s.close
    end
  end
end
```

### `Session`

```ruby
class AppleFoundationModel::Session
  def initialize(instructions: nil)
    if (reason = AppleFoundationModel.send(:__availability_reason))
      raise UnavailableError, "Apple Intelligence unavailable: #{reason}"
    end
    @native = AppleFoundationModel.const_get(:__Native).new(instructions)
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

  def close;   @closed = true; end
  def closed?; @closed;        end
end
```

- `model:` キーワードはどこにも無い。
- `configure` / `default_client` は無い。

### Error マッピング

| Swift / Apple FM 由来 | Ruby 側に飛ぶ Error |
|---|---|
| `SystemLanguageModel.default.availability == .unavailable(...)` | `UnavailableError`（reason メッセージ付き） |
| `LanguageModelSession.respond` の throw | `GenerationError` |
| `LanguageModelSession.streamResponse` ループ内 throw | `GenerationError` |
| closed Session への `respond` / `stream_response` | `Error` |
| `stream_response` を block 無しで呼ぶ | `ArgumentError`（既存テスト互換） |

## Swift / C bridge 詳細

### Swift (`ext/foundation_model_mac/Sources/FoundationModelMac/FoundationModelMac.swift`)

```swift
import Foundation
import FoundationModels   // Apple FM, macOS 26+

final class FMMSession {
    let session: LanguageModelSession
    init(instructions: String?) {
        if let i = instructions, !i.isEmpty {
            self.session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: i
            )
        } else {
            self.session = LanguageModelSession(model: SystemLanguageModel.default)
        }
    }
}

// 戻り値: NULL なら available、文字列なら unavailable + reason
@c
public func fmm_availability_check() -> UnsafeMutablePointer<CChar>? {
    switch SystemLanguageModel.default.availability {
    case .available:               return nil
    case .unavailable(let reason): return strdup("\(reason)")
    }
}

@c
public func fmm_session_new(
    _ instructions: UnsafePointer<CChar>?,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutableRawPointer? {
    error_out.pointee = nil
    let instr = instructions.map { String(cString: $0) }
    let s = FMMSession(instructions: instr)
    return Unmanaged.passRetained(s).toOpaque()
}

@c
public func fmm_session_free(_ ptr: UnsafeMutableRawPointer) {
    Unmanaged<FMMSession>.fromOpaque(ptr).release()
}

@c
public func fmm_session_respond(
    _ ptr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> UnsafeMutablePointer<CChar>? {
    error_out.pointee = nil
    let s = Unmanaged<FMMSession>.fromOpaque(ptr).takeUnretainedValue()
    let p = String(cString: prompt)

    let sem = DispatchSemaphore(value: 0)
    var out: Result<String, Error>!
    Task {
        do { out = .success(try await s.session.respond(to: p).content) }
        catch { out = .failure(error) }
        sem.signal()
    }
    sem.wait()

    switch out! {
    case .success(let txt): return strdup(txt)
    case .failure(let e):   error_out.pointee = strdup("\(e)"); return nil
    }
}

@c
public func fmm_session_stream(
    _ ptr: UnsafeMutableRawPointer,
    _ prompt: UnsafePointer<CChar>,
    _ callback: @convention(c) (UnsafePointer<CChar>) -> Void,
    _ error_out: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) {
    error_out.pointee = nil
    let s = Unmanaged<FMMSession>.fromOpaque(ptr).takeUnretainedValue()
    let p = String(cString: prompt)

    let sem = DispatchSemaphore(value: 0)
    var caught: Error? = nil
    Task {
        do {
            var prev = ""
            for try await partial in s.session.streamResponse(to: p) {
                let cum = partial.content
                if cum.hasPrefix(prev) && cum.count > prev.count {
                    let inc = String(cum.dropFirst(prev.count))
                    inc.withCString { callback($0) }
                    prev = cum
                } else if cum != prev {
                    cum.withCString { callback($0) }
                    prev = cum
                }
            }
        } catch { caught = error }
        sem.signal()
    }
    sem.wait()

    if let e = caught { error_out.pointee = strdup("\(e)") }
}
```

### C bridge (`ext/foundation_model_mac/foundation_model_mac.c`)

```c
#include <ruby.h>
#include <stdlib.h>
#include "FoundationModelMac-Swift.h"

static VALUE eFmm, eUnavail, eGen;

static void fmm_dfree(void *p) { if (p) fmm_session_free(p); }
static const rb_data_type_t fmm_dt = {
    "AppleFoundationModel::Session::Native",
    { NULL, fmm_dfree, NULL, },
    NULL, NULL, RUBY_TYPED_FREE_IMMEDIATELY,
};

static VALUE rb_fmm_availability(VALUE self) {
    char *r = fmm_availability_check();
    if (!r) return Qnil;
    VALUE s = rb_utf8_str_new_cstr(r);
    free(r);
    return s;
}

static VALUE rb_fmm_alloc(VALUE klass) {
    return TypedData_Wrap_Struct(klass, &fmm_dt, NULL);
}

static VALUE rb_fmm_init(int argc, VALUE *argv, VALUE self) {
    VALUE instr;
    rb_scan_args(argc, argv, "01", &instr);
    char *err = NULL;
    const char *c_instr = NIL_P(instr) ? NULL : StringValueCStr(instr);
    void *p = fmm_session_new(c_instr, &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    DATA_PTR(self) = p;
    return self;
}

static VALUE rb_fmm_respond(VALUE self, VALUE prompt) {
    void *p = DATA_PTR(self);
    char *err = NULL;
    char *res = fmm_session_respond(p, StringValueCStr(prompt), &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    VALUE r = rb_utf8_str_new_cstr(res);
    free(res);
    return r;
}

static void stream_cb(const char *chunk) {
    rb_yield(rb_utf8_str_new_cstr(chunk));
}

static VALUE rb_fmm_stream(VALUE self, VALUE prompt) {
    void *p = DATA_PTR(self);
    char *err = NULL;
    fmm_session_stream(p, StringValueCStr(prompt), stream_cb, &err);
    if (err) {
        VALUE m = rb_utf8_str_new_cstr(err);
        free(err);
        rb_raise(eGen, "%s", StringValueCStr(m));
    }
    return Qnil;
}

void Init_foundation_model_mac(void) {
    VALUE mod = rb_define_module("AppleFoundationModel");
    eFmm     = rb_const_get(mod, rb_intern("Error"));
    eUnavail = rb_const_get(mod, rb_intern("UnavailableError"));
    eGen     = rb_const_get(mod, rb_intern("GenerationError"));

    rb_define_singleton_method(mod, "__availability_reason", rb_fmm_availability, 0);

    VALUE cNative = rb_define_class_under(mod, "__Native", rb_cObject);
    rb_define_alloc_func(cNative, rb_fmm_alloc);
    rb_define_method(cNative, "initialize", rb_fmm_init,    -1);
    rb_define_method(cNative, "respond",    rb_fmm_respond,  1);
    rb_define_method(cNative, "stream",     rb_fmm_stream,   1);
}
```

### `lib/foundation_model_mac.rb` のロード順

Error クラスを **native ext を require する前に** 定義する（C 側 `Init_` で `rb_const_get` するため）。

```ruby
require_relative "foundation_model_mac/version"

module AppleFoundationModel
  class Error            < StandardError; end
  class UnavailableError < Error; end
  class GenerationError  < Error; end
end

require_relative "foundation_model_mac/foundation_model_mac"  # native .bundle
require_relative "foundation_model_mac/session"

module AppleFoundationModel
  def self.generate(prompt:, instructions: nil)
    s = Session.new(instructions: instructions)
    begin
      s.respond(to: prompt)
    ensure
      s.close
    end
  end

  private_class_method :__availability_reason
end
```

## Build / Packaging

### `ext/foundation_model_mac/extconf.rb`

```ruby
# frozen_string_literal: true
require "swift_gem/mkmf"

SwiftGem::Mkmf.create_swift_makefile(
  "foundation_model_mac/foundation_model_mac",
  package: "FoundationModelMac",
  source_dir: __dir__
)
```

### `ext/foundation_model_mac/Package.swift`

```swift
// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "FoundationModelMac",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "FoundationModelMac", type: .dynamic, targets: ["FoundationModelMac"])
    ],
    targets: [
        .target(name: "FoundationModelMac", path: "Sources/FoundationModelMac")
    ]
)
```

### `rb-foundation-model-mac.gemspec` 差分

- `spec.platform = Gem::Platform.new("arm64-darwin")` 追加（Apple Silicon 専用）
- `spec.extensions = ["ext/foundation_model_mac/extconf.rb"]` 追加
- `spec.add_runtime_dependency "swift_gem", "~> 0.1"` 追加（sibling repo 現行 0.1.0 系）
- `spec.summary` / `spec.description` を Apple FM 直結文言に書き換え（"Pure-Ruby ... backed by a local Ollama server" → "Native Apple Foundation Models for Ruby on macOS 26+"）

### `Rakefile`

```ruby
require "bundler/gem_tasks"
require "rake/extensiontask"
require "rake/testtask"

Rake::ExtensionTask.new("foundation_model_mac") do |ext|
  ext.lib_dir = "lib/foundation_model_mac"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

task test: :compile
task default: :test
```

### `.gitignore` 追加

```
ext/foundation_model_mac/.build/
ext/foundation_model_mac/Sources/FoundationModelMac/FoundationModelMac-Swift.h
ext/foundation_model_mac/Makefile
ext/foundation_model_mac/mkmf.log
lib/foundation_model_mac/foundation_model_mac.bundle
```

### `Gemfile`

`gem "swift_gem", path: "../swift_gem"` は **維持**（dev 中の sibling 参照）。

## Tests

### `test/test_helper.rb`

```ruby
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"
require "test-unit"

def apple_foundation_model_available?
  AppleFoundationModel::Session.new.close
  true
rescue AppleFoundationModel::UnavailableError
  false
end

def apple_foundation_model_unavailable_reason
  AppleFoundationModel::Session.new.close
  nil
rescue AppleFoundationModel::UnavailableError => e
  e.message
end
```

### `test/test_generate.rb`

`setup` を `apple_foundation_model_available?` ベースに置き換え。**`test_generate_uses_configured_model` は削除**（`model:` キーワード自体が消えるため）。

### `test/test_session.rb` / `test/test_streaming.rb`

`setup` の `omit` ガードを `apple_foundation_model_available?` 判定に差し替え。テスト本体（assertion）は **そのまま全件維持**（API 形が変わらないため）。

## Examples

`examples/basic_generation.rb`、`examples/multi_turn.rb`、`examples/streaming.rb` から `OLLAMA_*` 環境変数や Ollama 関連コメントを削除。コード本体は API 維持により無変更。

## README.md

全面書き直し：

- タイトル下: "On-device LLM inference for Ruby on macOS via the native Apple Foundation Models framework (Apple Intelligence)."
- Requirements: macOS 26+ / Apple Silicon / Apple Intelligence enabled / Ruby 3.2+ / Swift 6.3+
- Installation: `bundle add rb-foundation-model-mac`、Apple Intelligence 有効化手順への参照
- Usage: 既存 3 例（API 維持）
- Roadmap: 過去の roadmap を「達成済み」として撤去、新たな展望（Embeddings、tool calling）のみ簡潔に
- Ollama / 環境変数の言及完全削除

## 削除 / 新規 / 修正 / 不変ファイル一覧

### 削除
- `lib/foundation_model_mac/client.rb`
- `lib/foundation_model_mac/error.rb`（内容は `foundation_model_mac.rb` にインライン）
- README の Ollama 関連節すべて

### 新規
- `ext/foundation_model_mac/extconf.rb`
- `ext/foundation_model_mac/foundation_model_mac.c`
- `ext/foundation_model_mac/Package.swift`
- `ext/foundation_model_mac/Sources/FoundationModelMac/FoundationModelMac.swift`
- `lib/foundation_model_mac/session.rb`（差し替え新規作成）
- `docs/superpowers/specs/2026-05-06-apple-foundation-models-native-design.md`

### 修正
- `lib/foundation_model_mac.rb`
- `rb-foundation-model-mac.gemspec`
- `Rakefile`
- `.gitignore`
- `README.md`
- `examples/*.rb`
- `test/test_helper.rb`
- `test/test_generate.rb`
- `test/test_session.rb`
- `test/test_streaming.rb`

### 不変
- `Gemfile`
- `lib/foundation_model_mac/version.rb`
- `LICENSE.txt`
- `.swift-version`
- `.bundle/` / `vendor/bundle/`

## 重要な技術的注意

1. **GVL**: `rb_fmm_respond` / `rb_fmm_stream` は内部で `DispatchSemaphore.wait()` するため、その間 Ruby GVL を抱えたまま blocking する。Apple FM 推論は数秒オーダーかかるため、他 Ruby スレッドが stall する。今回は **シンプル追求でこの挙動を許容**する。問題化したら後で `rb_thread_call_without_gvl` + `rb_thread_call_with_gvl` パターンに移行する（後付け可能）。
2. **Streaming chunk の累積前提**: Apple FM の `streamResponse` partial が cumulative であることを前提に diff 切り出し。万一前提が崩れた場合 (新 partial が prev の prefix でない) は新 chunk として全文 yield する fallback を設ける。
3. **`@convention(c)` callback**: Swift クロージャを C 関数ポインタとして渡せる。ctx 引数は今回不使用（Ruby の `rb_yield` は thread-local の current frame の block を呼ぶため ctx 不要）。
4. **エラー識別の簡素化**: `UnavailableError` は availability check（`Session.new` 時）でしか raise されない設計。それ以外の Apple FM 由来エラーはすべて `GenerationError`。エラー種別 prefix の解析は不要。
5. **キャンセル / interrupt**: 今回スコープ外。Apple FM はキャンセル可能（Swift の `Task.cancel()`）だが、Ruby `Thread#raise` ↔ Swift Task のシグナル橋渡しは複雑度爆発するため後回し。

## TDD コミット境界

`~/dev/src/CLAUDE.md` の TDD ルール（RED / GREEN / REFACTOR は独立コミット）に従う。

- **RED**: テストを Apple FM 期待形に書き換え、`apple_foundation_model_available?` ベースに切り替え、`test_generate_uses_configured_model` を削除。この時点ではまだ実装無し → テスト全 omit（available 環境では fail、unavailable 環境では omit）。
- **GREEN**: Swift / C bridge / Ruby `Session` 新実装、Ollama コードを削除して全テストパス。
- **REFACTOR**: 必要に応じて。

各フェーズ独立コミット。

## 想定リスク

| リスク | 対応 |
|---|---|
| Swift FoundationModels API のシンボル名 / `availability` enum 名が想定と異なる | 実装フェーズ初期に `swift -e "import FoundationModels; print(...)"` 相当の探りを入れて確認、必要なら spec 更新 |
| `streamResponse` の partial が cumulative でなく incremental だった | Swift 側の diff 切り出しロジックの fallback 分岐がそのまま受ける（誤動作はせず一致確認できる） |
| `@convention(c)` クロージャが Swift 6.3 の `@c` 属性と衝突 | 衝突する場合は別ファイルに切り出す or `@_cdecl` を併用するパターンに切り替え |
| `arm64-darwin` プラットフォーム制約により Intel Mac の bundler install で reject される | 意図通り。Intel Mac は Apple Intelligence 非対応のためサポートしない |
| GVL 抱えっぱなしで他 Ruby スレッドが止まる | 既知の制約として README に明記。問題化したら後で GVL release 化 |

## 完成判定基準

1. `bundle exec rake test` が available 環境（macOS 26 + Apple Silicon + Apple Intelligence enabled）で全 PASS。
2. unavailable 環境（macOS < 26 or Apple Intelligence 未有効）で全 omit、エラー無し。
3. `examples/*.rb` を `bundle exec ruby examples/<file>.rb` で個別実行して期待通りの出力。
4. リポジトリ内に "ollama"・"OLLAMA_" 文字列が **README / コード / テスト / コメント / examples のいずれにも存在しない**（spec ファイル内の歴史的記述は除く）。
5. `Client` / `configure` / `default_client` / `model:` 引数 / `ConnectionError` / `APIError` の参照がコード内に残っていない。
