require "bundler/setup"
require "harmoniser"

Harmoniser.configure do |config|
  config.bunny = {host: "rabbitmq"}
end

class Publisher
  include Harmoniser::Publisher
  harmoniser_publisher name: "", type: :direct
end

# Retry strategy using default exchange with routing key to move to the waiting queue. The messages
# remain in waiting queue a total of TTL and once reached, using the default exchange are moved back
# to the original queue. The TTL is always a fixed value of 10 seconds
class Subscriber
  include Harmoniser::Subscriber
  harmoniser_queue_declare "my_queue", arguments: {"x-dead-letter-exchange": "", "x-dead-letter-routing-key": "a_queue_for_waiting"}
  harmoniser_queue_declare "a_queue_for_waiting", arguments: {"x-message-ttl": 10000, "x-dead-letter-exchange": "", "x-dead-letter-routing-key": "my_queue"}
  harmoniser_subscriber queue: "my_queue", no_ack: false

  def self.on_delivery(delivery_info, properties, payload)
    Harmoniser.logger.info({delivery_info: delivery_info, properties: properties, payload: payload})
    delivery_info.channel.nack(delivery_info.delivery_tag, false, false)
  end
end

Publisher.publish("Hello World!", routing_key: "my_queue")

begin
  loop {}
rescue Interrupt
  Harmoniser.logger.info({message: "Interrupted"})
end
