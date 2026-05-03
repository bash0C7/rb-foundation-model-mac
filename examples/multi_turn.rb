#!/usr/bin/env ruby
# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "foundation_model_mac"

session = AppleFoundationModel::Session.new(
  instructions: "You answer in one short sentence. Be precise."
)
puts "User: My name is Alice."
puts "Assistant: #{session.respond(to: 'My name is Alice.')}"
puts "User: What is my name?"
puts "Assistant: #{session.respond(to: 'What is my name?')}"
session.close
