require "bundler/setup"
require "json"
require "harmoniser"

Harmoniser.configure do |config|
  # Configure the connection options for connection to RabbitMQ
  config.connection_opts = {
    host: "rabbitmq"
  }
  # Define topology for unicast messaging
  config.define_topology do |topology|
    topology.add_exchange(:direct, "my_direct_exchange", durable: true)
    topology.add_queue("my_first_queue", durable: true)
    topology.add_queue("my_second_queue", durable: true)
    topology.add_binding("my_direct_exchange", "my_first_queue", routing_key: "foo")
    topology.add_binding("my_direct_exchange", "my_second_queue", routing_key: "bar")
    topology.declare
  end
end

# Create anonymous classes subscribed to the queues bound to the exchange
["my_first_queue", "my_second_queue"].each do |queue_name|
  Class.new do
    include Harmoniser::Subscriber
    harmoniser_subscriber queue_name: queue_name

    class << self
      def on_delivery(delivery_info, properties, payload)
        puts "Message received: queue = `#{delivery_info.consumer.queue}`, payload = `#{payload}`"
      end
    end
  end
end

# Create anonymous class for publishing messages through the exchange
Class.new do
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_direct_exchange"
end
  .publish({salute: "Hello foo!"}.to_json, routing_key: "foo")
  .publish({salute: "Hello bar!"}.to_json, routing_key: "bar")
