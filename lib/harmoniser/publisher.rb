require "harmoniser/connectable"
require "harmoniser/definition"

module Harmoniser
  # Publisher module provides functionality to publish messages to a RabbitMQ exchange. This module
  # has to be included in a class that needs to publish messages. It provides two class methods once
  # included:
  # - *harmoniser_publisher*: Defines the exchange to publish to.
  # - *publish*: Publishes a message to the exchange defined by the `harmoniser_publisher` method.
  # This module is thread-safe and will synchronize access to the exchange.
  # @see file:docs/publisher.md Publisher
  module Publisher
    class MissingExchangeDefinition < StandardError; end
    include Connectable

    module ClassMethods
      # Defines the exchange to publish to. This method must be called before calling
      # publish method. Do not call this method more than once in the context of a class.
      # This method does not create the exchange in RabbitMQ, it only defines the exchange name that
      # will be used for publishing messages. In order to create the exchange in RabbitMQ, you need
      # to define it through the topology DSL. See {Topology#add_exchange} for more information.
      #
      # @param exchange_name [String] The name of the exchange to publish to.
      # @return [Definition::Exchange] The exchange definition.
      def harmoniser_publisher(exchange_name:)
        @harmoniser_exchange_definition = Definition::Exchange.new(
          name: exchange_name,
          type: nil,
          opts: {passive: true}
        )
      end

      # Publishes a message to the exchange defined by the harmoniser_publisher method.
      # This method is thread-safe and will synchronize access to the exchange.
      # @param payload [String] The message payload to publish.
      # @param opts [Hash] Additional options for publishing the message.
      # @return [Bunny::Exchange] The exchange to which the message was published.
      # @raise [MissingExchangeDefinition] If the harmoniser_publisher method was not called
      # before this method.
      def publish(payload, opts = {})
        raise_missing_exchange_definition unless @harmoniser_exchange_definition

        const_get(:HARMONISER_PUBLISHER_MUTEX).synchronize do
          harmoniser_exchange.publish(payload, opts)
        end
        Harmoniser.logger.debug { "Message published: exchange = `#{@harmoniser_exchange_definition.name}`, payload = `#{payload}`, opts = `#{opts}`" }

        harmoniser_exchange
      end

      private

      def harmoniser_exchange
        @harmoniser_exchange ||= create_exchange
      end

      def create_exchange
        exchange = Bunny::Exchange.new(
          Publisher.create_channel,
          @harmoniser_exchange_definition.type,
          @harmoniser_exchange_definition.name,
          @harmoniser_exchange_definition.opts
        )
        handle_return(exchange)
        exchange
      end

      def raise_missing_exchange_definition
        raise MissingExchangeDefinition, "Please call the harmoniser_publisher class method at `#{name}` with the exchange_name that will be used for publishing"
      end

      def handle_return(exchange)
        exchange.on_return do |basic_return, properties, payload|
          Harmoniser.logger.warn("Default on_return handler executed for exchange: basic_return = `#{basic_return}`, properties = `#{properties}`, payload = `#{payload}`")
        end
      end
    end

    class << self
      # @!visibility private
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
