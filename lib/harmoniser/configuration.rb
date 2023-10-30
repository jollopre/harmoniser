require "forwardable"
require "logger"
require "harmoniser/connection"
require "harmoniser/topology"
require "harmoniser/options"

module Harmoniser
  class Configuration
    extend Forwardable

    DEFAULT_CONNECTION_OPTS = {
      connection_name: "harmoniser@#{VERSION}",
      host: "127.0.0.1",
      password: "guest",
      port: 5672,
      tls_silence_warnings: true,
      username: "guest",
      verify_peer: false,
      vhost: "/"
    }
    MUTEX = Mutex.new

    attr_reader :connection, :connection_opts, :logger, :options
    def_delegators :options, :environment, :require, :verbose

    def initialize
      @logger = Logger.new($stdout, progname: "harmoniser@#{VERSION}")
      @options = Options.new(**default_options)
      set_logger_severity
      @connection_opts = DEFAULT_CONNECTION_OPTS.merge({ logger: @logger })
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

    def options_with(**kwargs)
      @options = options.with(**kwargs)
      set_logger_severity
    end

    private

    def default_options
      {
        environment: ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "production")),
        require: ".",
        verbose: false
      }
    end

    def set_logger_severity
      if @options.production?
        @logger.level = @options.verbose? ? Logger::DEBUG : Logger::INFO
      else
        @logger.level = Logger::DEBUG
      end
    end
  end
end
