require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
  config.define_topology do |topology|
    topology.add_exchange(:topic, "production/ex/com.myorg.payments/main", durable: true)
    topology.add_queue("production/qu/payments/succeeded_use_case/com.myorg.payments")
    topology.add_binding(
      "production/ex/com.myorg.payments/main",
      "production/qu/payments/succeeded_use_case/com.myorg.payments",
      routing_key: "com.myorg.payments.1-0.event.charge.*"
    )
    topology.declare
  end
end
