require "bundler/setup"
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
  config.define_topology do |topology|
    env = "production"
    owner = "com.organisation.payments-service"
    service_name = "callback-service"
    exchange_name = "#{env}/ex/#{owner}/main"
    queue_name = "#{env}/qu/#{service_name}/a_use_case/#{owner}"

    # Definition of exchanges, queues and bindings
    topology.add_exchange(:topic, exchange_name, durable: true)
    topology.add_queue(queue_name)
    topology.add_binding(
      exchange_name,
      queue_name,
      routing_key: "#{owner}.1-0.event.payment.*"
    )
  end
end
