require "singleton"
require "harmoniser"
require "harmoniser/parser"
require "harmoniser/launcher"

module Harmoniser
  class CLI
    include Singleton

    SIGNAL_HANDLERS = {
      "INT" => lambda { |cli, signal| raise Interrupt },
      "TERM" => lambda { |cli, signal| raise Interrupt }
    }
    SIGNAL_HANDLERS.default = lambda { |cli, signal| cli.logger.info("Default signal handler executed since there is no handler defined: signal = `#{signal}`") }

    attr_reader :logger

    def initialize
      @configuration = Harmoniser.default_configuration
      @logger = Harmoniser.logger
    end

    def call
      parse_options
      define_signals
      run
    end

    private

    attr_reader :configuration

    def parse_options
      options = Parser.new(logger: @logger).call(ARGV)
      configuration.options_with(**options)
    end

    def define_signals
      @read_io, @write_io = IO.pipe

      ["INT", "TERM"].each do |sig|
        Signal.trap(sig) do
          @write_io.puts(sig)
        end
      end
    end

    def run
      Launcher
        .new(configuration: configuration, logger: logger)
        .start

      while @read_io.wait_readable
        signal = @read_io.gets.strip
        handle_signal(signal)
      end
    rescue Interrupt
      @write_io.close
      @read_io.close
      exit(0)
    end

    def handle_signal(signal)
      logger.info("Signal received: signal = `#{signal}`")
      SIGNAL_HANDLERS[signal].call(self, signal)
    end
  end
end
