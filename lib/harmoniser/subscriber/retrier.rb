require "harmoniser/subscriber/retrier_properties"

module Harmoniser
  module Subscriber
    class Retrier
      MAX_RETRIES = 2
      attr_reader :max_retries

      def initialize(channel:, klass:, max_retries: MAX_RETRIES, queue_name:)
        @channel = channel
        @klass = klass
        @max_retries = max_retries
        @queue_name = queue_name
        declare_exchange
        declare_queue
      end

      def try_on_delivery(delivery_info, properties, payload)
        klass.on_delivery(delivery_info, properties, payload)
      rescue => error
        retrier_properties = RetrierProperties.new(error, properties, self)
        # TODO safe thread publication
        return publisher.publish(
          payload,
          retrier_properties.next
        ) if retrier_properties.next?

        Harmoniser.logger.error("Default on_delivery_exhausted handler executed, message will not be re-delivered again: error_class = `#{error.class}`, error_message = `#{error.message}`, queue = `#{queue_name}`")
      end

      def awaiting_queue_name
        "harmoniser_#{queue_name}"
      end

      private

      attr_reader :channel, :publisher, :klass, :queue_name

      def declare_exchange
        @publisher = channel.default_exchange
      end

      def declare_queue
        # https://www.rabbitmq.com/dlx.html
        arguments = queue_opts.fetch(:arguments, {}).merge({ "x-dead-letter-exchange": "", "x-dead-letter-routing-key": queue_name })
        channel.queue_declare(awaiting_queue_name, queue_opts.merge({ arguments: arguments }))
      end

      def queue_opts
        topology = Harmoniser.configuration.instance_variable_get(:@topology)
        topology.queues.find do |queue|
          queue.name == queue_name
        end.opts
      end
    end
  end
end
