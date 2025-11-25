require "forwardable"

module Harmoniser
  class Channel
    extend Forwardable

    def_delegators :@bunny_channel,
      :exchange,
      :queue,
      :queue_bind

    attr_reader :bunny_channel

    def initialize(bunny_channel)
      @bunny_channel = bunny_channel
      after_initialize
    end

    private

    def after_initialize
      bunny_channel.cancel_consumers_before_closing!
      attach_callbacks
    end

    def attach_callbacks
      bunny_channel.on_error(&method(:on_error_callback).to_proc)
      bunny_channel.on_uncaught_exception(&method(:on_uncaught_exception_callback).to_proc)
    end

    def on_error_callback(channel, amq_method)
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
      Harmoniser.logger.warn("Default on_error handler executed for channel: #{stringified_attributes}")
      maybe_kill_process(amq_method)
    end

    def on_uncaught_exception_callback(error, consumer)
      handle_error(error, {description: "Uncaught exception from consumer", arguments: consumer.arguments, channel_id: consumer.channel.id, consumer_tag: consumer.consumer_tag, exclusive: consumer.exclusive, no_ack: consumer.no_ack, queue: consumer.queue})
    end

    def maybe_kill_process(amq_method)
      Process.kill("USR1", Process.pid) if ack_timed_out?(amq_method) && Harmoniser.server?
    end

    def ack_timed_out?(amq_method)
      return false unless amq_method.is_a?(AMQ::Protocol::Channel::Close)

      amq_method.reply_text =~ /delivery acknowledgement on channel \d+ timed out/
    end

    def handle_error(exception, ctx)
      Harmoniser.configuration.handle_error(exception, ctx)
    end
  end
end
