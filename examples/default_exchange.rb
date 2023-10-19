require "bundler/setup"
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = { host: "rabbitmq" }
end

class Publisher
  include Harmoniser::Publisher

  harmoniser_publisher exchange_name: ""
end

class Subscriber
  include Harmoniser::Subscriber

  harmoniser_queue_declare "my_queue", auto_delete: true
  harmoniser_subscriber queue: "my_queue"

  def self.on_delivery(delivery_info, properties, payload)
    Harmoniser.logger.info({message: payload})
  end
end

Publisher
  .publish("Hello World!", routing_key: "my_queue")
  .publish("Another Hello World!", routing_key: "my_queue")

sleep(5)
