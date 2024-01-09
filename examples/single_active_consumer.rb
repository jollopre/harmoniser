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
    topology.add_exchange(:fanout, "my_fanout_exchange", auto_delete: true)
    topology.add_queue("my_first_queue", arguments: { "x-single-active-consumer": true })
    topology.add_binding("my_fanout_exchange", "my_first_queue")
    topology.declare
  end
end

# Creates anonymous classes subscribed to the queue declared as single active consumer
(1..5).each do |i|
  Class.new do
    include Harmoniser::Subscriber
    harmoniser_subscriber queue_name: "my_first_queue", consumer_tag: "consumer-#{i}"

    class << self
      def on_delivery(delivery_info, properties, payload)
        consumer = delivery_info.consumer
        puts "Message received: queue = `#{consumer.queue}`, consumer = `#{consumer.consumer_tag}`, payload = `#{payload}`"
        consumer.cancel
      end
    end
  end
end

# Create class for publishing messages through the exchange
class Publisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_fanout_exchange"
end

Thread.new do
  (1..5).each do |i|
    sleep 10
    Publisher.publish({salute: "Hello foo (#{i})!"}.to_json)
  end
end
