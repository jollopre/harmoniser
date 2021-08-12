require "bunny"
require "benchmark"

puts "Share a channel anytime a message is published"

EVENT_NAME = "orders.create"
EXCHANGE_OPTS = {type: :fanout, durable: true}
MAX_THREADS = 15
MAX_MESSAGES = 1000

session = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: Logger.new($stdout)
}).start
shared_channel = session.create_channel

lambda do
  channel = session.create_channel
  exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  queue = channel.queue("orders.create.queue", durable: true)
  queue.bind(exchange)
  queue.subscribe({}) do |delivery_info, metadata, payload|
    pp "Message received, delivery_info: #{delivery_info}, metadata: #{metadata}, payload: #{payload}"
  end
end.call

publisher = lambda do |data|
  require "json"
  require "securerandom"
  exchange = shared_channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  exchange.publish(JSON.generate(data), {message_id: SecureRandom.uuid})
end

time = Benchmark.measure do
  (0..MAX_THREADS).map do |thread_number|
    Thread.new do
      (1..MAX_MESSAGES).each do |i|
        publisher.call({i: i})
      end
    end
  end.map(&:join)
end

puts "Elapsed real time: #{time.real}"
