require "singleton"
require "harmoniser"
require "harmoniser/parser"
require "harmoniser/launcher"
require "harmoniser/health"

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
      @queue = Thread::Queue.new
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
      ["INT", "TERM", "USR1"].each do |sig|
        Signal.trap(sig) do
          @queue.push(sig)
        end
      end
    end

    def run
      define_signals
      start_launcher
      Health::Server.new.call
      await_signal
    rescue Interrupt
      stop_launcher
      exit(0)
    rescue SigUsr1
      stop_launcher
      exit(128 + 10)
    end

    def await_signal
      signal = @queue.pop
      logger.info("Signal received: signal = `#{signal}`")
      SIGNAL_HANDLERS[signal].call(self, signal)
    end

    def start_launcher
      Thread.new do
        await_signal
      end.tap do |t|
        t.abort_on_exception = true
        t.report_on_exception = false
        @launcher.start
      end.kill
    end

    def stop_launcher
      @launcher.stop
    end
  end
end
