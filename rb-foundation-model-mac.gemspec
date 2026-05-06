# frozen_string_literal: true

require_relative "lib/foundation_model_mac/version"

Gem::Specification.new do |spec|
  spec.name = "rb-foundation-model-mac"
  spec.version = AppleFoundationModel::VERSION
  spec.authors = ["bash0C7"]
  spec.email = ["ksb.4038.nullpointer+github@gmail.com"]

  spec.summary = "Native Apple Foundation Models for Ruby on macOS 26+ (Apple Silicon)"
  spec.description = "rb-foundation-model-mac provides AppleFoundationModel.generate and Session, " \
    "directly backed by Apple's on-device FoundationModels framework (Apple Intelligence) " \
    "via a Swift native extension. Requires macOS 26+ on Apple Silicon."
  spec.homepage = "https://github.com/bash0C7/rb-foundation-model-mac"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bash0C7/rb-foundation-model-mac"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/foundation_model_mac/extconf.rb"]

  spec.add_runtime_dependency "swift_gem", "~> 0.1"
end
