require "bundler/setup"
require "harmoniser"
require "harmoniser/mock"

# Enable mock mode for testing
Harmoniser::Mock.mock!

# Capture topology instance to access declared_channel later
declared_topology = nil

Harmoniser.configure do |config|
  config.connection_opts = {host: "rabbitmq"}

  config.define_topology do |topology|
    # Configure topology like in production
    topology.add_exchange(:direct, "orders_exchange", durable: true)
    topology.add_exchange(:fanout, "notifications_exchange")
    topology.add_queue("orders_queue", durable: true, exclusive: false)
    topology.add_queue("notifications_queue")
    topology.add_binding("orders_exchange", "orders_queue", routing_key: "order.created")
    topology.add_binding("notifications_exchange", "notifications_queue")

    # Declare topology and capture reference
    declared_topology = topology
    topology.declare
  end
end

# Access mock channel to inspect what was declared
channel = declared_topology.declared_channel

# Assert topology was captured correctly
exchanges = channel.exchanges
queues = channel.queues
bindings = channel.bindings

puts "Mock Topology Results:"
puts "  Exchanges: #{exchanges.keys.join(", ")}"
puts "  Queues: #{queues.keys.join(", ")}"
puts "  Bindings: #{bindings.size}"

# Verify specific configurations
orders_exchange = exchanges["orders_exchange"]
orders_queue = queues["orders_queue"]

raise "Wrong exchange type" unless orders_exchange.type == :direct
raise "Wrong queue durability" unless orders_queue.opts[:durable] == true
raise "Wrong binding count" unless bindings.size == 2

puts "✓ All topology declarations captured in mock mode!"
