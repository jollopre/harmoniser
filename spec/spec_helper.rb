# frozen_string_literal: true

ENV["RABBITMQ_HOST"] ||= "127.0.0.1"

require "harmoniser"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
