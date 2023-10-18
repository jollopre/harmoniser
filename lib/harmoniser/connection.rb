require "forwardable"
require "bunny"

module Harmoniser
  class Connection
    extend Forwardable
    def_delegators :@bunny, :close, :create_channel, :open?, :start

    def initialize(opts)
      @bunny = Bunny.new(opts)
    end
  end
end
