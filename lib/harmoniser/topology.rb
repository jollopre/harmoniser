require "harmoniser/connectable"
require "harmoniser/definition"

module Harmoniser
  class Topology
    include Connectable

    attr_reader :bindings, :exchanges, :queues

    def initialize
      @bindings = Set.new
      @exchanges = Set.new
      @queues = Set.new
    end

    # Add an exchange to the topology. This method does not create the exchange in RabbitMQ, it only
    # defines the exchange name, its type (e.g. :direct, :fanout, :topic) and options that will be
    # used for creating the exchange in RabbitMQ. In order to create the exchange in RabbitMQ, you
    # need to call the declare method. See {#declare} for more information.
    # @param type [Symbol] The type of the exchange (e.g. :direct, :fanout, :topic).
    # @param name [String] The name of the exchange.
    # @param opts [Hash] The options for the exchange. Some of these options are explained below for quick referencee. See AMQP options[https://github.com/rabbitmq/amqp-0.9.1-spec/blob/main/docs/amqp-0-9-1-reference.md#parameters-16] for more information.
    #  * :durable [Boolean] - If true, the exchange will survive a broker restart.
    #  * :auto_delete [Boolean] - If true, the exchange will be deleted when no queues are
    #  * :arguments [Hash] - Additional arguments for the exchange.
    # @return [Topology] The topology instance.
    def add_exchange(type, name, **opts)
      @exchanges << Definition::Exchange.new(
        type: type,
        name: name,
        opts: opts
      )
      self
    end

    def add_queue(name, **opts)
      @queues << Definition::Queue.new(
        name: name,
        opts: opts
      )
      self
    end

    def add_binding(exchange_name, destination_name, destination_type = :queue, **opts)
      @bindings << Definition::Binding.new(
        exchange_name: exchange_name,
        destination_name: destination_name,
        destination_type: destination_type,
        opts: opts
      )
      self
    end

    def declare
      self.class.create_channel.tap do |ch|
        declare_exchanges(ch)
        declare_queues(ch)
        declare_bindings(ch)
        ch.connection.close
      end
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

        end
      end
    end
  end
end
