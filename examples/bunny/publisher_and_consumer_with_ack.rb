require "bunny"
require "benchmark"
require "json"
require "securerandom"

puts "A channel for publishing, another for consuming, with ACK for publishing and consuming"

EVENT_NAME = "orders.create"
EXCHANGE_OPTS = {type: :fanout, durable: true}

session = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: Logger.new($stdout)
}).start

Subscriber = Class.new do
  attr_reader :channel, :queue

  def initialize(session:, queue_name:)
    @session = session
    @queue_name = queue_name
    create_channel
    declare_exchange
    declare_queue
    subscribe
  end

  private

  attr_reader :session, :exchange, :consumer

  def create_channel
    @channel = session.create_channel
  end

  def declare_exchange
    @exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  end

  def declare_queue
    @queue = channel.queue(EVENT_NAME + "." + @queue_name, durable: true).bind(exchange)
  end

  def subscribe
    @consumer = queue.subscribe(manual_ack: true, &method(:on_delivery))
  end

  def on_delivery(delivery_info, message_properties, content)
    pp "delivery_info: #{delivery_info}, message_properties: #{message_properties}, content: #{content}"
    channel.ack(delivery_info.delivery_tag, false)
  end
end

Publisher = Class.new do
  attr_reader :channel

  def initialize(session)
    @session = session
    create_channel
    declare_exchange
  end

  def call(data)
    pp "Next publish seq_no: #{channel.next_publish_seq_no}"
    exchange.publish(JSON.generate(data), {message_id: SecureRandom.uuid, persistent: true})
  end

  private

  attr_reader :session, :exchange

  def create_channel
    @channel = session.create_channel
    @channel.confirm_select(method(:on_ack))
  end

  def declare_exchange
    @exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  end

  def on_ack(delivery_tag, unused_arg, nack)
    pp "published ACK received for delivery_tag: #{delivery_tag}, unused_arg: #{unused_arg}, nack: #{nack}"
  end
end

subscriber = Subscriber.new(session: session, queue_name: "queue")
result = Publisher.new(session).call({msg: SecureRandom.random_number})
pp "Message published, result: #{result}"

loop do
  puts "-------------------------------------"
  puts "Checking queue messages..."
  break if subscriber.queue.message_count == 0
  puts "Sleeping since the queue still has messages"
  sleep(1)
  puts "-------------------------------------"
end
