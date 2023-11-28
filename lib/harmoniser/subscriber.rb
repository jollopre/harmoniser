require "harmoniser/channelable"
require "harmoniser/definition"
require "harmoniser/includable"

module Harmoniser
  module Subscriber
    class MissingConsumerDefinition < StandardError; end
    include Channelable
    include Includable
    MUTEX = Mutex.new
    private_constant :MUTEX

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

      def harmoniser_subscriber_start
        MUTEX.synchronize do
          @harmoniser_consumer ||= create_consumer
        end
      end

      private

      def create_consumer
        raise_missing_consumer_definition unless @harmoniser_consumer_definition

        consumer = Bunny::Consumer.new(
          Subscriber.harmoniser_channel,
          @harmoniser_consumer_definition.queue_name,
          @harmoniser_consumer_definition.consumer_tag || Subscriber.harmoniser_channel.generate_consumer_tag,
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
        raise MissingConsumerDefinition, "Please, call harmoniser_subscriber class method first with the queue_name that will be used for subscribing"
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
        harmoniser_register_included(base)
      end
    end
  end
end
