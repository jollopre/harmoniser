require "harmoniser/channelable"

module Harmoniser
  module Publisher
    include Channelable
    MUTEX = Mutex.new
    private_constant :MUTEX

    module ClassMethods
      def harmoniser_publisher(name:, channel: nil, type: :fanout, opts: {})
        a_channel = channel || Publisher.harmoniser_channel
        MUTEX.synchronize do
          @harmoniser_exchange ||= Bunny::Exchange.new(
            a_channel,
            type,
            name,
            opts
          )
        end
        yield(@harmoniser_exchange) if block_given?
        @harmoniser_exchange
      end

      def publish(payload, opts = {})
        MUTEX.synchronize do
          @harmoniser_exchange
            .publish(payload, opts)
        end
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
