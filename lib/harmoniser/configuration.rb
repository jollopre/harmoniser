require "logger"
require "harmoniser/connection"
require "harmoniser/connection_opts"

module Harmoniser
  class Configuration
    MUTEX = Mutex.new
    attr_reader :connection, :connection_opts, :logger

    def initialize
      @logger = Logger.new($stdout)
      @connection_opts = DEFAULT_CONNECTION_OPTS
        .to_h
        .merge({ logger: @logger })
    end

    def connection
      MUTEX.synchronize do
        unless @connection
          @connection = Connection.new(connection_opts)
          @connection.start
        end

        @connection
      end
    end

    def connection_opts=(opts)
      raise TypeError, "opts must be a Hash object" unless opts.is_a?(Hash)

      @connection_opts = connection_opts.merge(opts)
    end
  end
end
