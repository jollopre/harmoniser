require "optparse"
require_relative "version"

module Harmoniser
  class Parser
    def initialize(logger:)
      @logger = logger
      @options = {}
      @option_parser = OptionParser.new do |opts|
        opts.banner = "harmoniser [options]"
        opts.on "-e", "--environment ENV", "Set the application environment (defaults to inferred environment or 'production')" do |arg|
          @options[:environment] = arg
        end
        opts.on "-r", "--require [PATH|DIR]", "Specify a file to require or the location of the Rails application" do |arg|
          @options[:require] = arg
        end
        opts.on("-v", "--[no-]verbose", "Run verbosely (set log severity to 'debug' for detailed RabbitMQ interactions)") do |arg|
          @options[:verbose] = arg
        end
        opts.on "-V", "--version", "Print version and exit" do
          puts "Harmoniser #{Harmoniser::VERSION}"
          exit(0)
        end
        opts.on_tail "-h", "--help", "Show help" do
          puts @option_parser
          exit(0)
        end
      end
    end

    def call(argv = [])
      @option_parser.parse!(argv)
      @options
    end
  end
end
