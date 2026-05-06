#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

prompt = ARGV[0] || "Rubyについて短く説明してください。"

response = AppleFoundationModel.generate(
  prompt: prompt,
  instructions: "日本語で簡潔に答えてください。"
)
puts response
