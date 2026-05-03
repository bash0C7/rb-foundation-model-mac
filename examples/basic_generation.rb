#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

response = AppleFoundationModel.generate(
  prompt: "Name three programming languages, comma separated.",
  instructions: "Reply with only the comma-separated list, no extra text."
)
puts response
