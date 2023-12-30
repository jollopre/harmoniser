require "harmoniser/channelable"
require "harmoniser/definition"

module Harmoniser
  module Publisher
    class MissingExchangeDefinition < StandardError; end
    include Channelable

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

        const_get(:HARMONISER_PUBLISHER_MUTEX).synchronize do
          harmoniser_exchange.publish(payload, opts)
        end
        Harmoniser.logger.debug { "Message published: payload = `#{payload}`, opts = `#{opts}`" }

        harmoniser_exchange
      end

      private

      def harmoniser_exchange
        @harmoniser_exchange ||= Bunny::Exchange.new(
          Publisher.create_channel,
          @harmoniser_exchange_definition.type,
          @harmoniser_exchange_definition.name,
          @harmoniser_exchange_definition.opts
        )
      end

      def raise_missing_exchange_definition
        raise MissingExchangeDefinition, "Please, call harmoniser_publisher class method first with the exchange_name that will be used for publications"
      end
    end

    class << self
      def included(base)
        base.const_set(:HARMONISER_PUBLISHER_MUTEX, Mutex.new)
        base.extend(ClassMethods)
      end
    end
  end
end
