require "harmoniser/channelable"

module Harmoniser
  module Subscriber
    include Channelable
    MUTEX = Mutex.new
    private_constant :MUTEX

    module ClassMethods
      attr_reader :harmoniser_consumer

      def harmoniser_queue_declare(name, opts = {})
        a_channel = Subscriber.harmoniser_channel
        a_channel.queue_declare(name, opts)
      end

      def harmoniser_queue_bind(name, exchange, opts = {})
        a_channel = Subscriber.harmoniser_channel
        a_channel.queue_bind(name, exchange, opts)
      end

      def harmoniser_subscriber(queue:, channel: nil, consumer_tag: nil, no_ack: true, exclusive: false, arguments: {})
        a_channel = channel || Subscriber.harmoniser_channel
        MUTEX.synchronize do
          @harmoniser_consumer ||= Bunny::Consumer.new(
            a_channel,
            queue,
            consumer_tag || a_channel.generate_consumer_tag,
            no_ack,
            exclusive,
            arguments
          )
        end
        yield(@harmoniser_consumer) if block_given?
        @harmoniser_consumer
      end

      def singleton_method_added(id)
        if id == :on_delivery
          on_delivery_instrumenter
        elsif id == :on_cancellation
          on_cancellation_instrumenter
        end
      end

      def on_delivery_instrumenter
        @harmoniser_consumer.on_delivery do |delivery_info, properties, payload|
          on_delivery(delivery_info, properties, payload)
        end
        @harmoniser_consumer
          .channel
          .basic_consume_with(@harmoniser_consumer)
      end

      def on_cancellation_instrumenter
        @harmoniser_consumer.on_cancellation do |basic_cancel|
          on_cancellation(basic_cancel)
        end
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
        base.private_class_method :on_delivery_instrumenter, :on_cancellation_instrumenter
      end
    end
  end
end
