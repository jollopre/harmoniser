require "harmoniser/channelable"

module Harmoniser
  class Topology
    include Channelable

    Exchange = Data.define(:name, :type, :opts) do
      def hash
        [self.class, name].hash
      end

      def eql?(other)
        self.class == other.class && name == other.name
      end
    end

    Queue = Data.define(:name, :opts) do
      def hash
        [self.class, name].hash
      end

      def eql?(other)
        self.class == other.class && name == other.name
      end
    end

    Binding = Data.define(:exchange_name, :destination_name, :destination_type, :opts) do
      def queue?
        [:queue, "queue"].include?(destination_type)
      end

      def exchange?
        [:exchange, "exchange"].include?(destination_type)
      end
    end

    attr_reader :bindings, :exchanges, :queues

    def initialize
      @bindings = Set.new
      @exchanges = Set.new
      @queues = Set.new
    end

    def add_exchange(type, name, **opts)
      @exchanges << Exchange.new(
        type: type,
        name: name,
        opts: opts
      )
    end

    def add_queue(name, **opts)
      @queues << Queue.new(
        name: name,
        opts: opts
      )
    end

    def add_binding(exchange_name, destination_name, destination_type = :queue, **opts)
      @bindings << Binding.new(
        exchange_name: exchange_name,
        destination_name: destination_name,
        destination_type: destination_type,
        opts: opts
      )
    end

    def declare
      channel = self.class.create_channel
      declare_exchanges(channel)
      declare_queues(channel)
      declare_bindings(channel)
    end

    private

    def declare_exchanges(channel)
      exchanges.each do |exchange|
        Bunny::Exchange.new(channel, exchange.type, exchange.name, exchange.opts)
      end
    end

    def declare_queues(channel)
      queues.each do |queue|
        Bunny::Queue.new(channel, queue.name, queue.opts)
      end
    end

    def declare_bindings(channel)
      bindings.each do |binding|
        if binding.queue?
          channel.queue_bind(binding.destination_name, binding.exchange_name, binding.opts)
        elsif binding.exchange?
          ;
        end
      end
    end
  end
end
