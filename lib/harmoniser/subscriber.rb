require "harmoniser/channelable"
require "harmoniser/definition"
require "harmoniser/includable"
require "harmoniser/subscriber/retrier"

module Harmoniser
  module Subscriber
    class MissingConsumerDefinition < StandardError; end
    include Channelable
    include Includable

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
        const_get(:HARMONISER_SUBSCRIBER_MUTEX).synchronize do
          @harmoniser_consumer ||= create_consumer
        end
      end

      private

      def create_consumer
        raise_missing_consumer_definition unless @harmoniser_consumer_definition

        channel = Subscriber.create_channel
        consumer = Bunny::Consumer.new(
          channel,
          @harmoniser_consumer_definition.queue_name,
          @harmoniser_consumer_definition.consumer_tag || channel.generate_consumer_tag,
          @harmoniser_consumer_definition.no_ack,
          @harmoniser_consumer_definition.exclusive,
          @harmoniser_consumer_definition.arguments
        )
        retrier = Retrier.new(channel: channel, klass: self, max_retries: 2, queue_name: @harmoniser_consumer_definition.queue_name)
        handle_cancellation(consumer)
        handle_delivery(consumer, retrier)
        handle_uncaught_exception(consumer)
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

      def handle_delivery(consumer, retrier)
        consumer.on_delivery do |delivery_info, properties, payload|
          if respond_to?(:on_delivery)
            retrier.try_on_delivery(delivery_info, properties, payload)
          else
            Harmoniser.logger.info("Default on_delivery handler executed for consumer: consumer_tag = `#{consumer.consumer_tag}`, queue = `#{consumer.queue}`")
          end
        end
      end

      def handle_uncaught_exception(consumer)
        consumer.channel.on_uncaught_exception(&method(:on_uncaught_exception).to_proc)
      end

      def on_uncaught_exception(error, consumer)
        Harmoniser.logger.error("Default on_uncaught_exception handler executed for channel: error_class = `#{error.class}`, error_message = `#{error.message}`, error_backtrace = `#{error.backtrace&.first(5)}, queue = `#{consumer.queue}`")
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
        base.const_set(:HARMONISER_SUBSCRIBER_MUTEX, Mutex.new)
        base.extend(ClassMethods)
        harmoniser_register_included(base)
      end
    end
  end
end
