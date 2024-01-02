require "bundler/setup"
require "json"
require "harmoniser"

Harmoniser.configure do |config|
  # Configure the connection options for connection to RabbitMQ
  config.connection_opts = {
    host: "rabbitmq"
  }
  # Define topology
  config.define_topology do |topology|
    topology.add_exchange(:direct, "my_exchange_without_queues", auto_delete: true)
    topology.declare
  end
end

# Create anonymous class for publishing messages through the exchange
Class.new do
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_exchange_without_queues"
end
  .publish({salute: "Hello foo!"}.to_json, routing_key: "foo")
  .publish({salute: "Hello foo returned!"}.to_json, routing_key: "foo", mandatory: true)
