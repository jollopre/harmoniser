require "harmoniser/connectable"
require "harmoniser/definition"

module Harmoniser
  module Publisher
    class MissingExchangeDefinition < StandardError; end

    class ConnectionNotReady < StandardError; end

    include Connectable

    module ClassMethods
      def harmoniser_publisher(exchange_name:)
        @harmoniser_exchange_definition = Definition::Exchange.new(
          name: exchange_name,
          type: nil,
          opts: {passive: true}
        )
      end

      def publish(payload, opts = {})
        raise_missing_exchange_definition unless @harmoniser_exchange_definition

        connection, channel, exchange = harmoniser_publisher_resources
        channel.synchronize do
          raise_connection_not_ready unless connection.ready?
          exchange.publish(payload, opts)
        end
        Harmoniser.logger.debug { "Message published: exchange = `#{@harmoniser_exchange_definition.name}`, payload = `#{payload}`, opts = `#{opts}`" }

        exchange
      end

      private

      def harmoniser_publisher_resources
        const_get(:HARMONISER_PUBLISHER_MUTEX).synchronize do
          unless @harmoniser_exchange
            connection = Publisher.connection
            raise_connection_not_ready unless connection.ready?
            channel = Publisher.create_channel
            @harmoniser_exchange = create_exchange(channel)
            @harmoniser_channel = channel
            @harmoniser_connection = connection
          end
          [@harmoniser_connection, @harmoniser_channel, @harmoniser_exchange]
        end
      end

      def create_exchange(channel)
        exchange = channel
          .exchange(
            @harmoniser_exchange_definition.name,
            {type: @harmoniser_exchange_definition.type}.merge(@harmoniser_exchange_definition.opts)
          )
        handle_return(exchange)
        exchange
      end

      def raise_missing_exchange_definition
        raise MissingExchangeDefinition, "Please call the harmoniser_publisher class method at `#{name}` with the exchange_name that will be used for publishing"
      end

      def raise_connection_not_ready
        raise ConnectionNotReady, "Connection is not ready for publishing to exchange `#{@harmoniser_exchange_definition.name}`, it is either closed or recovering from a network failure"
      end

      def handle_return(exchange)
        exchange.on_return do |basic_return, properties, payload|
          Harmoniser.logger.warn("Default on_return handler executed for exchange: basic_return = `#{basic_return}`, properties = `#{properties}`, payload = `#{payload}`")
        end
      end
    end

    class << self
      def included(base)
        base.const_set(:HARMONISER_PUBLISHER_MUTEX, Mutex.new)
        base.private_constant(:HARMONISER_PUBLISHER_MUTEX)
        base.extend(ClassMethods)
      end
    end

    at_exit do
      next if Harmoniser.server?
      next unless Publisher.connection?
      Publisher.connection.close
    end
  end
end
