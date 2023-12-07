module Harmoniser
  module Channelable
    MUTEX = Mutex.new
    private_constant :MUTEX

    module ClassMethods
      def harmoniser_channel
        MUTEX.synchronize do
          @harmoniser_channel ||= create_channel
        end
      end

      def create_channel
        channel = Harmoniser.connection.create_channel
        channel.on_error(&method(:on_error).to_proc)
        channel.on_uncaught_exception(&method(:on_uncaught_exception).to_proc)
        channel
      end

      private

      def on_error(channel, amq_method)
        Harmoniser.logger.error("Default on_error handler executed for channel: method = `#{amq_method}`, exchanges = `#{channel.exchanges.keys}`, queues = `#{channel.queues.keys}`")
      end

      def on_uncaught_exception(error, consumer)
        Harmoniser.logger.error("Default on_uncaught_exception handler executed for channel: error_class = `#{error.class}`, error_message = `#{error.message}`, error_backtrace = `#{error.backtrace&.first(5)}, queue = `#{consumer.queue}`")
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
