#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

session = AppleFoundationModel::Session.new(
  instructions: "日本語で丁寧に、わかりやすく答えてください。"
)

# ARGV からプロンプトを読み込む
prompts = if ARGV.empty?
  [
    "macOSとは何ですか？",
    "Rubyの特徴を教えてください。",
    "これまでの説明をまとめてください。"
  ]
else
  ARGV
end

prompts.each do |prompt|
  puts "質問: #{prompt}"
  response = session.respond(to: prompt)
  puts "回答: #{response}"
  puts
end

session.close
