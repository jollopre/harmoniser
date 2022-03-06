require 'logger'
logger = Logger.new(STDOUT, level: :INFO)

create_session = lambda do
  require 'bunny'
  Bunny.new({
    host: "rabbitmq",
    port: 5672,
    username: "guest",
    password: "guest",
    vhost: "/",
    logger: logger
  }).start
end

create_channel = lambda do |session|
  channel = session.create_channel
  channel.prefetch(1)
  channel
end

declare_exchange = lambda do |channel|
  EXCHANGE_OPTS = {type: :fanout, durable: true}
  channel.exchange("orders.create", EXCHANGE_OPTS)
end

declare_queue = lambda do |channel|
  QUEUE_OPTS = { durable: true, arguments: { :"x-single-active-consumer" => true} }
  channel.queue("orders.create.queue", QUEUE_OPTS)
end

create_publisher = lambda do |create_session, create_channel, declare_exchange, declare_queue|
  fork do
    require 'securerandom'
    require 'json'
    pid = Process.pid
    payload = { tags: ["publisher"], message: "Starting", pid: pid }
    puts payload.to_json
    session = create_session.call
    channel = create_channel.call(session)
    exchange = declare_exchange.call(channel)
    loop do
      begin
        id = SecureRandom.uuid
        exchange.publish(JSON.generate(id: id))
        sleep(Random.rand(5))
      rescue SignalException => e
        payload = { tags: ["publisher"], message: "signal received. Process will finish", signo: e.signo, pid: pid }
        puts payload
        declare_queue.call(channel).purge
        channel.close
        session.close
        exit(true)
      end
    end
  end
end

create_subscriber = lambda do |create_session, create_channel, declare_exchange, declare_queue|
  fork do
    require 'json'
    pid = Process.pid
    payload = { tags: ["subscriber"], message: "Starting", pid: pid }
    puts payload.to_json
    session = create_session.call
    channel = create_channel.call(session)
    exchange = declare_exchange.call(channel)
    queue = declare_queue.call(channel)
    queue.bind(exchange)
    consumer = queue.subscribe(manual_ack: true) do |delivery_info, message_properties, content|
      payload = { tags: ["subscriber"], message: "message received", content: content, pid: pid, queue_status: queue.status }
      puts payload.to_json

      sleep(10)
      queue.channel.ack(delivery_info.delivery_tag, false)

      payload = { tags: ["subscriber"], message: "message processed", content: content, pid: pid, queue_status: queue.status }
      puts payload.to_json
    end
    begin
      sleep
    rescue SignalException => e
      payload = { tags: ["subscriber"], message: "signal received. Process will finish", signo: e.signo, pid: pid, queue_status: queue.status }
      puts payload.to_json
      consumer.cancel
      channel.close
      session.close
      exit(true)
    end
  end
end
# Planifier
lambda do |create_session, create_channel, declare_exchange, declare_queue|
  require 'json'
  subscriber_pids = Queue.new
  subscriber_pids << create_subscriber.call(create_session, create_channel, declare_exchange, declare_queue)
  subscriber_pids << create_subscriber.call(create_session, create_channel, declare_exchange, declare_queue)
  publisher_pid = create_publisher.call(create_session, create_channel, declare_exchange, declare_queue)

  loop do
    begin
      sleep(20)
      pid = subscriber_pids.pop
      Process.kill("TERM", pid)
      subscriber_pids << create_subscriber.call(create_session, create_channel, declare_exchange, declare_queue)
      payload = { tags: ["planifier"], message: "spawning a new subscriber" }
      puts payload.to_json
    rescue SignalException => e
      Process.kill("TERM", publisher_pid)
      while subscriber_pids.length > 0
        pid = subscriber_pids.pop(false)
        Process.kill("TERM", pid)
      end
      Process.waitall
      payload = { tags: ["planifier"], message: "signal received", signo: e.signo, pid: Process.pid }
      puts payload.to_json
      exit(true)
    end
  end
end.call(create_session, create_channel, declare_exchange, declare_queue)
