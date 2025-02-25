require "harmoniser/version"
require "harmoniser/configurable"
require "harmoniser/loggable"
require "harmoniser/publisher"
require "harmoniser/subscriber"
require "harmoniser/health"

module Harmoniser
  extend Configurable
  extend Loggable

  class << self
    def server?
      !!defined?(CLI)
    end

    def ping
      Health::Client
        .new
        .ping == "pong"
    end
  end
end
