require "harmoniser/channelable"
require_relative "base"

module Harmoniser
  module Launcher
    class Bounded < Base
      include Channelable

      private

      def start_subscribers
        @consumers = subscribers.map do |klass|
          klass.harmoniser_subscriber_start(channel: channel)
        end
      end

      def channel
        @channel ||= self.class.create_channel(consumer_pool_size: @configuration.concurrency, consumer_pool_shutdown_timeout: @configuration.timeout)
      end
    end
  end
end
