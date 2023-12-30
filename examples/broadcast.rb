require "bundler/setup"
require "json"
require "harmoniser"

Harmoniser.configure do |config|
  # Configure the connection options for connection to RabbitMQ
  config.connection_opts = {
    host: "rabbitmq"
  }
  # Define topology for broadcast messaging
  config.define_topology do |topology|
    topology.add_exchange(:fanout, "my_fanout_exchange", auto_delete: true)

    ["my_first_queue", "my_second_queue", "my_third_queue"].each do |queue_name|
      topology.add_queue(queue_name, auto_delete: true)
      topology.add_binding("my_fanout_exchange", queue_name)
    end

    topology.declare
  end
end

# Create anonymous classes subscribed to the queues bound to the exchange
["my_first_queue", "my_second_queue", "my_third_queue"].each do |queue_name|
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
  harmoniser_publisher exchange_name: "my_fanout_exchange"
end.publish({salute: "Hello World!"}.to_json)
