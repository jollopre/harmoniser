require "harmoniser/connection"

module Harmoniser
  module Connectable
    MUTEX = Mutex.new

    module ClassMethods
      def connection(configuration = Harmoniser.configuration)
        MUTEX.synchronize do
          @connection ||= Connection.new(configuration.connection_opts)
          @connection.start unless @connection.open? || @connection.recovering_from_network_failure?
          @connection
        end
      end

      def connection?
        !!defined?(@connection)
      end

      def create_channel(consumer_pool_size: 1, consumer_pool_shutdown_timeout: 60)
        connection
          .create_channel(nil, consumer_pool_size, false, consumer_pool_shutdown_timeout)
          .tap do |channel|
            attach_callbacks(channel)
          end
      end

      private

      def attach_callbacks(channel)
        channel.on_error(&method(:on_error).to_proc)
        channel.on_uncaught_exception(&method(:on_uncaught_exception).to_proc)
      end

      def on_error(channel, amq_method)
        attributes = {
          amq_method: amq_method,
          exchanges: channel.exchanges.keys,
          queues: channel.consumers.values.map(&:queue)
        }

        if amq_method.is_a?(AMQ::Protocol::Channel::Close)
          attributes[:reply_code] = amq_method.reply_code
          attributes[:reply_text] = amq_method.reply_text
        end

        stringified_attributes = attributes.map { |k, v| "#{k} = `#{v}`" }.join(", ")
        Harmoniser.logger.error("Default on_error handler executed for channel: #{stringified_attributes}")
        maybe_kill_process(amq_method)
      end

      def on_uncaught_exception(error, consumer)
        Harmoniser.logger.error("Default on_uncaught_exception handler executed for channel: error_class = `#{error.class}`, error_message = `#{error.message}`, error_backtrace = `#{error.backtrace&.first(5)}, queue = `#{consumer.queue}`")
      end

      def maybe_kill_process(amq_method)
        Process.kill("USR1", Process.pid) if ack_timed_out?(amq_method) && Harmoniser.server?
      end

      def ack_timed_out?(amq_method)
        return false unless amq_method.is_a?(AMQ::Protocol::Channel::Close)

        amq_method.reply_text =~ /delivery acknowledgement on channel \d+ timed out/
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
