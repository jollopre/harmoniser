require "forwardable"
require "harmoniser/connectable"
require "harmoniser/topology"
require "harmoniser/options"

module Harmoniser
  class Configuration
    extend Forwardable
    include Connectable

    attr_reader :logger, :options
    def_delegators :options, :environment, :require, :verbose

    def initialize
      @logger = Harmoniser.logger
      @options = Options.new(**default_options)
      set_logger_severity
      @topology = Topology.new
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
        environment: ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "production")),
        require: ".",
        verbose: false
      }
    end

    def set_logger_severity
      @logger.level = @options.verbose? ? Logger::DEBUG : Logger::INFO
    end
  end
end
