require "harmoniser/version"
require "harmoniser/configurable"
require "harmoniser/loggable"
require "harmoniser/publisher"
require "harmoniser/subscriber"

module Harmoniser
  extend Configurable
  extend Loggable

  class << self
    def server?
      !!defined?(CLI)
    end
  end
end
