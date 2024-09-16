require "delegate"

module Harmoniser
  class WorkPoolReporter
    def initialize(consumers:, logger: Harmoniser.logger)
      @channels = build_channels(consumers)
      @logger = logger
    end

    def to_s
      "<#{self.class.name}>: #{channels_to_s}"
    end

    private

    def channels_to_s
      @channels.map do |(channel, queues)|
        channel_info(channel, queues.to_a)
      end
    end

    def channel_info(channel, queues)
      work_pool = channel.work_pool
      "<#{channel.id}>: backlog = `#{work_pool.backlog}`, running? = `#{work_pool.running?}`, queues = `#{queues}`"
    end

    def build_channels(consumers)
      initial = Hash.new { |hash, key| hash[key] = Set.new }
      consumers.each_with_object(initial) do |consumer, acc|
        acc[DecoratedChannel.new(consumer.channel)] << consumer.queue
      end
    end

    class DecoratedChannel < SimpleDelegator
      def id
        __getobj__.id
      end

      def hash
        id.hash
      end

      def eql?(other)
        other.is_a?(DecoratedChannel) && id == other.id
      end
    end
  end
end
