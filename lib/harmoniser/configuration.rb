require "forwardable"
require "harmoniser/connection"
require "harmoniser/topology"
require "harmoniser/options"

module Harmoniser
  class Configuration
    extend Forwardable

    attr_reader :logger, :options
    def_delegators :options, :concurrency, :environment, :require, :verbose, :timeout

    def initialize
      @logger = Harmoniser.logger
      @options = Options.new(**default_options)
      set_logger_severity
      @topology = Topology.new
    end

    def connection_opts
      @connection_opts ||= Connection::DEFAULT_CONNECTION_OPTS
    end

    def connection_opts=(opts)
      raise TypeError, "opts must be a Hash object" unless opts.is_a?(Hash)

      @connection_opts = connection_opts.merge(opts)
    end

    def define_topology
      raise LocalJumpError, "A block is required for this method" unless block_given?

      yield(@topology)
    end

    def options_with(**)
      @options = options.with(**)
      set_logger_severity
    end

    private

    def default_options
      {
        concurrency: Float::INFINITY,
        environment: ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "production")),
        require: ".",
        timeout: 25,
        verbose: false
      }
    end

    def set_logger_severity
      @logger.level = @options.verbose? ? Logger::DEBUG : Logger::INFO
    end
  end
end
