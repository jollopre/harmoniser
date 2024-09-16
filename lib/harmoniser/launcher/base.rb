require "harmoniser/subscriber"
require "harmoniser/subscriber/registry"
require "harmoniser/work_pool_reporter"

module Harmoniser
  module Launcher
    class Base
      attr_reader :subscribers

      def initialize(configuration:, logger:)
        @configuration = configuration
        @logger = logger
        @subscribers = Subscriber.registry
      end

      def start
        boot_app
        start_subscribers
        @logger.info("Subscribers registered to consume messages from queues: klasses = `#{@subscribers}`")
      end

      def stop
        @logger.info("Shutting down!")
        maybe_close
        @logger.info("Bye!")
      end

      private

      def boot_app
        if File.directory?(@configuration.require)
          load_rails
        else
          load_file
        end
      end

      def load_rails
        filepath = File.expand_path("#{@configuration.require}/config/environment.rb")
        require filepath
      rescue LoadError => e
        @logger.warn("Error while requiring file within directory. No subscribers will run for this process: require = `#{@configuration.require}`, filepath = `#{filepath}`, error_class = `#{e.class}`, error_message = `#{e.message}`, error_backtrace = `#{e.backtrace&.first(5)}`")
      end

      def load_file
        require @configuration.require
      rescue LoadError => e
        @logger.warn("Error while requiring file. No subscribers will run for this process: require = `#{@configuration.require}`, error_class = `#{e.class}`, error_message = `#{e.message}`, error_backtrace = `#{e.backtrace&.first(5)}`")
      end

      def maybe_close
        return unless @configuration.connection?
        return unless @configuration.connection.open?

        maybe_cancel_subscribers
        report_work_pool

        connection = @configuration.connection
        @logger.info("Connection will be closed: connection = `#{connection}`")
        connection.close
        @logger.info("Connection closed: connection = `#{connection}`")
      end

      def maybe_cancel_subscribers
        @logger.info("Subscribers will be cancelled from queues: klasses = `#{@subscribers}`")
        @subscribers.each(&:harmoniser_subscriber_stop)
        @logger.info("Subscribers cancelled: klasses = `#{@subscribers}`")
      end

      def report_work_pool
        @logger.info("Stats about the work pool: work_pool_reporter = `#{WorkPoolReporter.new(consumers: @consumers)}`. Note: A backlog greater than zero means messages could be lost for subscribers configured with no_ack, i.e. automatic ack")
      end
    end
  end
end
