require "logger"
require "harmoniser/connection"
require "harmoniser/connection_opts"
require "harmoniser/topology"

module Harmoniser
  class Configuration
    MUTEX = Mutex.new
    attr_reader :connection, :connection_opts, :logger

    def initialize
      @logger = Logger.new($stdout)
      @connection_opts = DEFAULT_CONNECTION_OPTS
        .to_h
        .merge({ logger: @logger })
      @topology = Topology.new
    end

    def define_topology
      raise LocalJumpError, "A block is required for this method" unless block_given?

      yield(@topology)
    end

    def connection
      MUTEX.synchronize do
        @connection = Connection.new(connection_opts) unless @connection
        @connection.start unless @connection.open?
        @connection
      end
    end

    def connection_opts=(opts)
      raise TypeError, "opts must be a Hash object" unless opts.is_a?(Hash)

      @connection_opts = connection_opts.merge(opts)
    end
  end
end
