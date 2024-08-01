require "singleton"
require "harmoniser"
require "harmoniser/parser"
require "harmoniser/launcher"

module Harmoniser
  class CLI
    class SigUsr1 < StandardError; end
    include Singleton

    SIGNAL_HANDLERS = {
      "INT" => lambda { |cli, signal| raise Interrupt },
      "TERM" => lambda { |cli, signal| raise Interrupt },
      "USR1" => lambda { |cli, signal| raise SigUsr1 }
    }
    SIGNAL_HANDLERS.default = lambda { |cli, signal| cli.logger.info("Default signal handler executed since there is no handler defined: signal = `#{signal}`") }

    attr_reader :logger

    def initialize
      @configuration = Harmoniser.default_configuration
      @logger = Harmoniser.logger
    end

    def call
      parse_options
      @launcher = Launcher.call(configuration: @configuration, logger: @logger)
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

      ["INT", "TERM", "USR1"].each do |sig|
        Signal.trap(sig) do
          @write_io.puts(sig)
        end
      end
    end

    def run
      @launcher.start

      define_signals

      while @read_io.wait_readable
        signal = @read_io.gets.strip
        handle_signal(signal)
      end
    rescue Interrupt
      @write_io.close
      @read_io.close
      @launcher.stop
      exit(0)
    rescue SigUsr1
      @write_io.close
      @read_io.close
      @launcher.stop
      exit(128 + 10)
    end

    def handle_signal(signal)
      logger.info("Signal received: signal = `#{signal}`")
      SIGNAL_HANDLERS[signal].call(self, signal)
    end
  end
end
