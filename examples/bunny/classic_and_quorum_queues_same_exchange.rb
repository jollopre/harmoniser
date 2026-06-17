require "bunny"
require "logger"
require "json"

logger = Logger.new($stdout, level: :INFO)
connection = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: logger
}).start

# Define Topology
ch = connection.create_channel
Bunny::Exchange.new(ch, :fanout, "mixed_exchange")
Bunny::Queue.new(ch, "classic_queue", durable: true, auto_delete: false)
Bunny::Queue.new(ch, "quorum_queue", durable: true, auto_delete: false, arguments: {"x-queue-type" => "quorum"})
ch.queue_bind("classic_queue", "mixed_exchange")
ch.queue_bind("quorum_queue", "mixed_exchange")
ch.close

# Create Publisher
ch2 = connection.create_channel
publisher = Bunny::Exchange.new(ch2, nil, "mixed_exchange", {passive: true})
payload = {hello: "World", id: 1}
publisher.publish(payload.to_json)
logger.info("Message published to both queues: payload = `#{payload}`")

sleep 1

inspect_ch = connection.create_channel
classic_check = Bunny::Queue.new(inspect_ch, "classic_queue", passive: true)
quorum_check = Bunny::Queue.new(inspect_ch, "quorum_queue", passive: true)
logger.info("classic_queue message_count = `#{classic_check.message_count}`")
logger.info("quorum_queue message_count = `#{quorum_check.message_count}`")
inspect_ch.close

ch2.close
connection.close
logger.info("Bye!")

###
# ruby examples/bunny/classic_and_quorum_queues_same_exchange.rb
