require "harmoniser/connection"
require "harmoniser/channel"

module Harmoniser
  module Connectable
    MUTEX = Mutex.new

    module ClassMethods
      def connection(configuration = Harmoniser.configuration)
        MUTEX.synchronize do
          @connection ||= Connection.new(configuration.connection_opts, error_handler: configuration.error_handler)
          @connection.start unless @connection.open? || @connection.recovering_from_network_failure?
          @connection
        end
      end

      def connection?
        !!defined?(@connection)
      end

      def create_channel(consumer_pool_size: 1, consumer_pool_shutdown_timeout: 60)
        connection
          .create_channel(nil, consumer_pool_size, false, consumer_pool_shutdown_timeout)
          .yield_self { |bunny_channel| Channel.new(bunny_channel) }
          .tap { |channel| connection.register_channel(channel) }
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
