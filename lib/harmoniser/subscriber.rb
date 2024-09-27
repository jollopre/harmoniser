require "harmoniser/connectable"
require "harmoniser/definition"
require "harmoniser/subscriber/registry"

module Harmoniser
  module Subscriber
    class MissingConsumerDefinition < StandardError; end
    include Connectable

    module ClassMethods
      def harmoniser_subscriber(queue_name:, consumer_tag: nil, no_ack: true, exclusive: false, arguments: {})
        @harmoniser_consumer_definition = Definition::Consumer.new(
          queue_name: queue_name,
          consumer_tag: consumer_tag,
          no_ack: no_ack,
          exclusive: exclusive,
          arguments: arguments
        )
      end

      def harmoniser_subscriber_start(channel: nil)
        const_get(:HARMONISER_SUBSCRIBER_MUTEX).synchronize do
          @harmoniser_consumer ||= create_consumer(channel)
        end
      end

      def harmoniser_subscriber_stop
        return unless @harmoniser_consumer
        return unless @harmoniser_consumer.channel.open?

        @harmoniser_consumer.cancel
      end

      def harmoniser_subscriber_to_s
        definition = @harmoniser_consumer_definition
        "<#{name}>: queue_name = `#{definition.queue_name}`, no_ack = `#{definition.no_ack}`"
      end

      private

      def create_consumer(channel)
        raise_missing_consumer_definition unless @harmoniser_consumer_definition

        ch = channel || Subscriber.create_channel
        consumer = Bunny::Consumer.new(
          ch,
          @harmoniser_consumer_definition.queue_name,
          @harmoniser_consumer_definition.consumer_tag || ch.generate_consumer_tag,
          @harmoniser_consumer_definition.no_ack,
          @harmoniser_consumer_definition.exclusive,
          @harmoniser_consumer_definition.arguments
        )
        handle_cancellation(consumer)
        handle_delivery(consumer)
        register_consumer(consumer)
        consumer
      end

      def handle_cancellation(consumer)
        consumer.on_cancellation do |basic_cancel|
          if respond_to?(:on_cancellation)
            on_cancellation(basic_cancel)
          else
            Harmoniser.logger.info("Default on_cancellation handler executed for consumer: consumer_tag = `#{consumer.consumer_tag}`, queue = `#{consumer.queue}`")
          end
        end
      end

      def handle_delivery(consumer)
        consumer.on_delivery do |delivery_info, properties, payload|
          Harmoniser.logger.debug { "Message received by a consumer: consumer_tag = `#{consumer.consumer_tag}, `payload = `#{payload}`, queue = `#{consumer.queue}`" }
          if respond_to?(:on_delivery)
            on_delivery(delivery_info, properties, payload)
          else
            Harmoniser.logger.info("Default on_delivery handler executed for consumer: consumer_tag = `#{consumer.consumer_tag}`, queue = `#{consumer.queue}`")
          end
        end
      end

      def register_consumer(consumer)
        consumer.channel.basic_consume_with(consumer)
      end

      def raise_missing_consumer_definition
        raise MissingConsumerDefinition, "Please call the harmoniser_subscriber class method at `#{name}` with the queue_name that will be used for subscribing"
      end
    end

    class << self
      def included(base)
        base.const_set(:HARMONISER_SUBSCRIBER_MUTEX, Mutex.new)
        base.private_constant(:HARMONISER_SUBSCRIBER_MUTEX)
        registry << base
        base.extend(ClassMethods)
      end

      def registry
        @registry ||= Registry.new
      end
    end
  end
end
