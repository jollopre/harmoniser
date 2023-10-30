require "bundler/setup"
require "json"
require "harmoniser"

$env = "production"
$owner = "com.organisation.payments-service"
$service_name = "callback-service"
$exchange_name = "#{$env}/ex/#{$owner}/main"
$queue_name = "#{$env}/qu/#{$service_name}/a_use_case/#{$owner}"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
  config.define_topology do |topology|
    topology.add_exchange(:topic, $exchange_name, durable: true)
    topology.add_queue($queue_name)
    topology.add_binding(
      $exchange_name,
      $queue_name,
      routing_key: "#{$owner}.1-0.event.payment.*"
    )
    topology.declare
  end
end

class PaymentPubSub
  include Harmoniser::Publisher
  include Harmoniser::Subscriber

  harmoniser_publisher exchange_name: $exchange_name
  harmoniser_subscriber queue_name: $queue_name

  class << self
    def on_delivery(delivery_info, properties, payload)
      Harmoniser.logger.info({
        body: "message received",
        payload: payload
      }.to_json)
    end
  end
end

# start subscriber
PaymentPubSub.harmoniser_subscriber_start
# publish message
PaymentPubSub.publish({ foo: "bar" }.to_json)
# publish another message
PaymentPubSub.publish({ foo: "bar" }.to_json, routing_key: "#{$owner}.1-0.event.payment.initiated")

sleep(2)
