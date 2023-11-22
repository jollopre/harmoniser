require "forwardable"
require "bunny"

module Harmoniser
  class Connection
    extend Forwardable
    def_delegators :@bunny, :close, :create_channel, :open?, :start

    def initialize(opts)
      @bunny = Bunny.new(opts)
    end

    def to_s
      "<#{self.class.name}>: #{user}@#{host}:#{port}, vhost = #{vhost}"
    end

    private

    def host
      @bunny.transport.host
    end

    def port
      @bunny.transport.port
    end

    def user
      @bunny.user
    end

    def vhost
      @bunny.vhost
    end
  end
end
