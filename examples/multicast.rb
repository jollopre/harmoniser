require "bundler/setup"
require "json"
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
  config.define_topology do |topology|
    topology.add_exchange(:topic, "my_topic_exchange", durable: true)
    topology.add_queue("my_queue", durable: true)
    topology.add_binding(
      "my_topic_exchange",
      "my_queue",
      routing_key: "my_resource.foo.*"
    )
    topology.declare
  end
end

class MyPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_topic_exchange"
end

class MySubscriber
  include Harmoniser::Subscriber
  harmoniser_subscriber queue_name: "my_queue"

  class << self
    def on_delivery(delivery_info, properties, payload)
      Harmoniser.logger.info({
        body: "message received",
        payload: payload
      }.to_json)
    end
  end
end

# Publish a message without routing key. It will not be push into `my_queue`
MyPublisher.publish({salute: "Dropped Hello World!"}.to_json)
# Publish a message with routing key matching the binding defined between `my_topic_exchange` and `my_queue`.
MyPublisher.publish({salute: "Hello World!"}.to_json, routing_key: "my_resource.foo.bar")
