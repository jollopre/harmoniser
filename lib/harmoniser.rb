require "harmoniser/version"
require "harmoniser/configurable"
require "harmoniser/publisher"

module Harmoniser
  extend Configurable
  # at_exit do
  #   puts "*" * 80
  #   puts "at_exit fired"
  #   puts "*" * 80
  # end

  # Signal.trap "SIGINT" do
  #   puts "*" * 80
  #   puts "Received SIGINT"
  #   puts "*" * 80
  #   exit(0)
  # end
end
