require "bunny"
require "benchmark"
require "json"
require "securerandom"

puts "A channel/exchange per publisher (multi thread) with publishing async ACKs"

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

queue = lambda do
  channel = session.create_channel
  exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  queue = channel.queue("orders.create.queue", durable: true)
  queue.bind(exchange)
  queue
end.call

Publisher = Class.new do
  attr_reader :channel

  def initialize(session)
    @session = session
    create_channel
    declare_exchange
  end

  def call(data)
    exchange.publish(JSON.generate(data), {message_id: SecureRandom.uuid, persistent: true})
  end

  private

  attr_reader :session, :exchange

  def create_channel
    @channel = session.create_channel
    @channel.confirm_select(callback)
  end

  def declare_exchange
    @exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  end

  def callback
    lambda do |delivery_tag, unused_arg, nack|
      pp "published ACK received for delivery_tag: #{delivery_tag}, unused_arg: #{unused_arg}, nack: #{nack}"
    end
  end
end

time = Benchmark.measure do
  (1..MAX_THREADS).map do |thread_number|
    Thread.new do
      publisher = Publisher.new(session)
      (1..MAX_MESSAGES).each do |i|
        publisher.call({i: i, msg: SecureRandom.random_number})
      end
    end
  end.map(&:join)
end

sleep(5)
puts "Processed all published messages. #{queue.name} has #{queue.message_count} messages"
queue.purge
puts "Elapsed real time: #{time.real}"
