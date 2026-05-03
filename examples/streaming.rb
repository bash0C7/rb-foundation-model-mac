#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

session = AppleFoundationModel::Session.new(
  instructions: "You are a friendly assistant. Reply in 2-3 sentences."
)
session.stream_response(to: "Why is the sky blue?") do |chunk|
  $stdout.print(chunk)
  $stdout.flush
end
puts
session.close
