# frozen_string_literal: true

require "harmoniser/mock/connection"
require "harmoniser/mock/channel"
require "harmoniser/connectable"

module Harmoniser
  module Mock
    @mocked = false
    @prepended = false

    class << self
      def mock!
        unless @prepended
          @prepended = true
          Harmoniser::Connectable::ClassMethods.prepend(MockConnectableMethods)
        end
        @mocked = true
      end

      def disable!
        @mocked = false
      end

      def mocked?
        @mocked
      end

      def disabled?
        !@mocked
      end
    end

    module MockConnectableMethods
      def connection(configuration = Harmoniser.configuration)
        return super unless Harmoniser::Mock.mocked?

        Harmoniser::Connectable::MUTEX.synchronize do
          @mock_connection ||= Harmoniser::Mock::Connection.new(configuration.connection_opts, error_handler: configuration.error_handler)
          @mock_connection.start unless @mock_connection.open? || @mock_connection.recovering_from_network_failure?
          @mock_connection
        end
      end

      def connection?
        return super unless Harmoniser::Mock.mocked?
        !!defined?(@mock_connection)
      end

      def create_channel(consumer_pool_size: 1, consumer_pool_shutdown_timeout: 60)
        return super unless Harmoniser::Mock.mocked?
        connection.create_channel(nil, consumer_pool_size, false, consumer_pool_shutdown_timeout)
      end
    end
  end
end
