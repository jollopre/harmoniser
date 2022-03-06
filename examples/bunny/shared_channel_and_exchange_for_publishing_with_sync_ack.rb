require "bunny"
require "benchmark"
require "json"
require "securerandom"

puts "Share a channel/exchange anytime a message is published (multi thread) with publishing sync ACKs"

EVENT_NAME = "orders.create"
EXCHANGE_OPTS = {type: :fanout, durable: true}
MAX_THREADS = 16
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
shared_channel.confirm_select
shared_exchange = shared_channel.exchange(EVENT_NAME, EXCHANGE_OPTS)

queue = lambda do
  channel = session.create_channel
  exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  queue = channel.queue("orders.create.queue", durable: true)
  queue.bind(exchange)
  queue
end.call

publisher = lambda do |data|
  shared_exchange.publish(JSON.generate(data), {message_id: SecureRandom.uuid, persistent: true})
end

time = Benchmark.measure do
  (1..MAX_THREADS).map do |thread_number|
    Thread.new do
      (1..MAX_MESSAGES).each do |i|
        publisher.call({i: i, msg: SecureRandom.random_number})
      end
    end
  end.map(&:join)
end

pp "Awaiting for confirmations..."
result = shared_channel.wait_for_confirms

if !result
  pp "unconfirmed_set #{shared_channel.unconfirmed_set}"
  pp "nacked_set: #{shared_channel.nacked_set}"
end

puts "Processed all published messages. #{queue.name} has #{queue.message_count} messages"
queue.purge
puts "Elapsed real time: #{time.real}"
