require "bunny"
require "logger"
require "json"

CONCURRENCY = ARGV[0].to_i
PREFETCH_COUNT = (ARGV[1]&.to_i == 0) ? nil : ARGV[1].to_i
MANUAL_ACK = ARGV[2].match?(/^true$/)

logger = Logger.new($stdout, level: :DEBUG)
connection = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: logger
}).start

# Define Topology
ch1 = connection.create_channel
Bunny::Exchange.new(ch1, :fanout, "a_exchange")
Bunny::Queue.new(ch1, "a_queue1", durable: true, auto_delete: false).purge
Bunny::Queue.new(ch1, "a_queue2", durable: true, auto_delete: false).purge
ch1.queue_bind("a_queue1", "a_exchange")
ch1.queue_bind("a_queue2", "a_exchange")
ch1.close

# Create Publisher
ch2 = connection.create_channel
publisher = Bunny::Exchange.new(ch2, nil, "a_exchange", {passive: true})

# Create Channel
subscribers_channel = lambda do |concurrency, prefetch_count|
  ch = connection.create_channel(nil, concurrency)
  ch.basic_qos(prefetch_count) unless prefetch_count.nil?
  ch.on_error do |ch, amq_method|
    logger.error("Error produced in the channel: amp_method = `#{amq_method}`, reply_code = `#{amq_method.reply_code}`, reply_text = `#{amq_method.reply_text}`")
  end
  ch
end.call(CONCURRENCY, PREFETCH_COUNT)

create_consumer = lambda do |queue_name, tag, no_ack, waiting_time|
  consumer = Bunny::Consumer.new(subscribers_channel, queue_name, tag, no_ack)
  consumer.on_delivery do |delivery_info, properties, payload|
    sleep(waiting_time)

    id, _ = JSON.parse(payload, symbolize_names: true).values_at(:id)
    raise "Unexpected error" if id == 5

    subscribers_channel.basic_ack(delivery_info.delivery_tag) unless consumer.no_ack
    logger.info("Message processed by a consumer: consumer_tag = `#{consumer.consumer_tag}`, `payload = `#{payload}`, queue = `#{consumer.queue}`")
  end
  consumer.on_cancellation do |basic_consume|
    logger.info("Default on_cancellation handler executed for consumer")
  end
end

c1 = create_consumer.call("a_queue1", "c1", !MANUAL_ACK, 60)
c2 = create_consumer.call("a_queue2", "c2", !MANUAL_ACK, 60)
subscribers_channel.basic_consume_with(c1)
subscribers_channel.basic_consume_with(c2)

# Publish on a separate thread
Thread.abort_on_exception = true
Thread.new do
  id = 0
  loop do
    payload = {hello: "World", id: id += 1}
    publisher.publish(payload.to_json)
    logger.info("Message published: payload = `#{payload}`")
    (id % 10 == 0) ? sleep(60) : sleep(1)
  end
end

# Stats for subscribers_channel
Thread.new do
  loop do
    work_pool = subscribers_channel.work_pool
    logger.info("Stats: work_pool = `#{work_pool.backlog}`, number_of_threads = `#{work_pool.threads.size}`, prefetch_count = `#{subscribers_channel.prefetch_count}`, prefetch_global = `#{subscribers_channel.prefetch_global}`")
    sleep 1
  end
end

begin
  sleep
rescue SignalException
  puts "Cancelling all the subscribers"
  logger.info("Subscribers are going to be cancelled")
  work_pool = subscribers_channel.work_pool
  c1.cancel
  c2.cancel
  puts "Messages might be still in progress since work pool size is `#{work_pool.backlog}`" if work_pool.busy?
  connection.close
  logger.info("Bye!")
end

###
# ruby examples/concurrency.rb CONCURRENCY PREFETCH_COUNT MANUAL_ACK
# ruby examples/concurrency.rb 2 4 true
