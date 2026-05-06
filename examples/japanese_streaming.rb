#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

prompt = ARGV[0] || "人工知能についてについて、詳しく説明してください。"

session = AppleFoundationModel::Session.new(
  instructions: "日本語で丁寧に説明してください。"
)

puts "質問: #{prompt}"
puts "回答: "
session.stream_response(to: prompt) do |chunk|
  $stdout.print(chunk)
  $stdout.flush
end
puts
session.close
