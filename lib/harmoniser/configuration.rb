require "bunny"
require "logger"

module Harmoniser
  class Configuration
    attr_reader :bunny, :logger

    def initialize
      @logger = Logger.new($stdout)
    end

    def bunny=(value)
      if value.is_a?(Bunny::Session)
        @bunny = value
      elsif value.is_a?(Hash)
        @bunny = Bunny.new({logger: @logger}.merge(value))
      else
        raise ArgumentError.new("Hash or Bunny argument is expected")
      end
    end
  end
end
