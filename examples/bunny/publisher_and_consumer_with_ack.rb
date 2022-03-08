require "bunny"
require "benchmark"
require "json"
require "securerandom"

puts "Publisher with ack confirmation, subscriber with ack"

EVENT_NAME = "orders.create"
EXCHANGE_OPTS = {type: :fanout, durable: true}

session = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: Logger.new($stdout, level: :INFO)
}).start

Publisher = Class.new do
  attr_reader :channel

  def initialize(session)
    @session = session
    create_channel
    declare_exchange
  end

  def call(data)
    payload = {tags: ["publisher"], message: "Publishing a message", data: data, next_publish_seq_no: channel.next_publish_seq_no}
    pp payload.to_json
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
    payload = {tags: ["publisher"], message: "ack received", delivery_tag: delivery_tag, unused_arg: unused_arg, nack: nack}
    pp payload.to_json
  end
end

Subscriber = Class.new do
  attr_reader :channel, :queue, :consumer

  def initialize(session:, queue_name:)
    @session = session
    @queue_name = queue_name
    @channel = create_channel
    @exchange = declare_exchange
    @queue = declare_queue
    @consumer = subscribe
  end

  private

  attr_reader :session, :exchange

  def create_channel
    channel = session.create_channel
    # 1 message to pre-fetch per consumer
    channel.basic_qos(1, false)
    channel
  end

  def declare_exchange
    channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  end

  def declare_queue
    queue = channel.queue(EVENT_NAME + "." + @queue_name, durable: true).bind(exchange)
    payload = {tags: ["subscriber"], message: "queue status", queue: queue.name, message_count: queue.message_count}
    pp payload.to_json
    queue
  end

  def subscribe
    queue.subscribe(manual_ack: true, &method(:on_delivery))
  end

  def on_delivery(delivery_info, message_properties, content)
    payload = {tags: ["subscriber"], message: "message received", delivery_info: delivery_info, message_properties: message_properties, content: content}
    pp payload.to_json
    sleep 5
    # channel.ack(delivery_info.delivery_tag, false)
    raise StandardError.new("An exception ocurred")
  rescue => e
    payload = {tags: ["subscriber"], message: "exception occurred", exception: {class: e.class, message: e.message}}
    pp payload.to_json
    channel.basic_reject(delivery_info.delivery_tag, true)
  end
end

publisher = Publisher.new(session).call({msg: SecureRandom.random_number})
subscriber = Subscriber.new(session: session, queue_name: "queue")

begin
  sleep
rescue SignalException => e
  payload = {tags: ["planifier"], message: "signal received", signo: e.signo}
  puts payload.to_json
  subscriber.consumer.cancel
  subscriber.channel.close
  publisher.channel.close
  session.close
end
