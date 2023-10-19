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
  BASE_DELAY = 5000
  include Harmoniser::Subscriber
  harmoniser_queue_declare "my_queue"
  harmoniser_queue_declare "a_queue_for_waiting", arguments: {"x-dead-letter-exchange": "", "x-dead-letter-routing-key": "my_queue"}
  harmoniser_subscriber queue: "my_queue"

  def self.on_delivery(delivery_info, properties, payload)
    Harmoniser.logger.info({delivery_info: delivery_info, properties: properties, payload: payload})
    retry_count = current_retry_count(properties)
    expiration = retry_delay(retry_count)
    Publisher.publish(payload, routing_key: "a_queue_for_waiting", expiration: expiration, headers: {"x-retries": retry_count + 1})
  end

  class << self
    def current_retry_count(properties)
      properties[:headers]["x-retries"].to_i
    rescue
      0
    end

    def retry_delay(retry_count)
      BASE_DELAY * (retry_count + 1)
    end
  end
end

Publisher.publish("Hello World!", routing_key: "my_queue")

begin
  loop {}
rescue Interrupt
  Harmoniser.logger.info({message: "Interrupted"})
end
