require "bunny"
require "benchmark"
require "json"
require "securerandom"

puts "Share a channel/exchange anytime a message is published (multi process)"
# With this approach, we are getting different errors such as :
# - frame errors (e.g. W, [2021-08-12T08:08:20.146699 #59]  WARN -- #<Bunny::Session:0x460 guest@rabbitmq:5672, vhost=/, addresses=[rabbitmq:5672]>: Recovering from connection.close (FRAME_ERROR - type 3, first 16 octets = <<1,0,0,0,22,0,60,0,40,0,0,13,111,114,100,101>>: {invalid_frame_end_marker,54}).
# - IOError (e.g.g E, [2021-08-12T08:27:37.952441 #50] ERROR -- #<Bunny::Session:0x460 guest@rabbitmq:5672, vhost=/, addresses=[rabbitmq:5672]>: Uncaught exception from consumer #<Bunny::Consumer:600 @channel_id=2 @queue=orders.create.queue> @consumer_tag=bunny-1628756855000-33589345417>: #<IOError: stream closed in another thread> @ /usr/local/lib/ruby/3.0.0/delegate.rb:349:in `write')

EVENT_NAME = "orders.create"
EXCHANGE_OPTS = {type: :fanout, durable: true}
MAX_PROCESSES = 16
MAX_MESSAGES = 10000

session = Bunny.new({
  host: "rabbitmq",
  port: 5672,
  username: "guest",
  password: "guest",
  vhost: "/",
  logger: Logger.new($stdout)
}).start
shared_channel = session.create_channel
shared_exchange = shared_channel.exchange(EVENT_NAME, EXCHANGE_OPTS)

queue = lambda do
  channel = session.create_channel
  exchange = channel.exchange(EVENT_NAME, EXCHANGE_OPTS)
  queue = channel.queue("orders.create.queue", durable: true)
  queue.bind(exchange)
end.call

publisher = lambda do |data|
  shared_exchange.publish(JSON.generate(data), {message_id: SecureRandom.uuid})
end

time = Benchmark.measure do
  pids = (1..MAX_PROCESSES).map do |process_number|
    fork do
      (1..MAX_MESSAGES).each do |i|
        publisher.call({i: i, msg: SecureRandom.random_number})
      rescue SignalException => e
        pp "Signal `#{Signal.signame(e.signo)}` received."
        break
      end
    end
  end

  Signal.trap("INT") do
    puts "Parent process interrumped"
  end

  pids.map do |pid|
    Thread.new do
      Process.waitpid(pid)
    end
  end.map(&:join)
end

puts "Processed published messages. #{queue.name} has #{queue.message_count} messages"
queue.purge
puts "Elapsed real time: #{time.real}"
