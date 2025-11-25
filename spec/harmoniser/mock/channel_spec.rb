# frozen_string_literal: true

require "harmoniser/mock/channel"

RSpec.describe Harmoniser::Mock::Channel do
  let(:channel) { described_class.new }

  describe "#initialize" do
    it "initializes empty collections" do
      expect(channel.exchanges).to eq({})
      expect(channel.queues).to eq({})
      expect(channel.bindings).to eq([])
    end
  end

  describe "#exchange" do
    let(:exchange_name) { "test_exchange" }
    let(:exchange_type) { "direct" }
    let(:exchange_opts) { {durable: true, auto_delete: false} }

    it "creates and returns a MockExchange with hash opts" do
      opts = {type: exchange_type}.merge(exchange_opts)
      result = channel.exchange(exchange_name, opts)

      expect(result).to be_a(Harmoniser::Mock::Channel::MockExchange)
      expect(result.name).to eq(exchange_name)
      expect(result.type).to eq(exchange_type)
      expect(result.opts).to eq(exchange_opts)
    end

    it "returns the same instance for the same exchange name" do
      result1 = channel.exchange(exchange_name)
      result2 = channel.exchange(exchange_name)

      expect(result1).to be(result2)
    end

    it "stores the exchange in the exchanges collection" do
      exchange = channel.exchange(exchange_name, {type: exchange_type})

      expect(channel.exchanges[exchange_name]).to be(exchange)
    end

    it "creates different instances for different exchange names" do
      exchange1 = channel.exchange("exchange1")
      exchange2 = channel.exchange("exchange2")

      expect(exchange1).not_to be(exchange2)
    end
  end

  describe "#queue" do
    let(:queue_name) { "test_queue" }
    let(:queue_opts) { {durable: true, exclusive: false} }

    it "creates and returns a MockQueue" do
      result = channel.queue(queue_name, queue_opts)

      expect(result).to be_a(Harmoniser::Mock::Channel::MockQueue)
      expect(result.name).to eq(queue_name)
      expect(result.opts).to eq(queue_opts)
    end

    it "returns the same instance for the same queue name" do
      result1 = channel.queue(queue_name)
      result2 = channel.queue(queue_name)

      expect(result1).to be(result2)
    end

    it "stores the queue in the queues collection" do
      queue = channel.queue(queue_name, queue_opts)

      expect(channel.queues[queue_name]).to be(queue)
    end
  end

  describe "#queue_bind" do
    let(:destination_name) { "test_queue" }
    let(:exchange_name) { "test_exchange" }
    let(:binding_opts) { {routing_key: "test.key"} }

    it "records the binding and returns true" do
      result = channel.queue_bind(destination_name, exchange_name, binding_opts)

      expect(result).to be(true)
      expect(channel.bindings).to include({
        destination_name: destination_name,
        exchange_name: exchange_name,
        opts: binding_opts
      })
    end

    it "records multiple bindings" do
      channel.queue_bind("queue1", "exchange1", {routing_key: "key1"})
      channel.queue_bind("queue2", "exchange2", {routing_key: "key2"})

      expect(channel.bindings.size).to eq(2)
      expect(channel.bindings[0]).to eq({
        destination_name: "queue1",
        exchange_name: "exchange1",
        opts: {routing_key: "key1"}
      })
      expect(channel.bindings[1]).to eq({
        destination_name: "queue2",
        exchange_name: "exchange2",
        opts: {routing_key: "key2"}
      })
    end
  end

  describe "#reset!" do
    before do
      channel.exchange("test_exchange")
      channel.queue("test_queue")
      channel.queue_bind("test_queue", "test_exchange", {})
    end

    it "clears all exchanges, queues, and bindings" do
      channel.reset!

      expect(channel.exchanges).to be_empty
      expect(channel.queues).to be_empty
      expect(channel.bindings).to be_empty
    end
  end

  describe "inspection methods return copies" do
    let(:exchange) { channel.exchange("test_exchange") }
    let(:queue) { channel.queue("test_queue") }

    before do
      exchange
      queue
      channel.queue_bind("test_queue", "test_exchange", {})
    end

    it "exchanges returns a copy" do
      exchanges_copy = channel.exchanges
      exchanges_copy.clear

      expect(channel.exchanges).not_to be_empty
    end

    it "queues returns a copy" do
      queues_copy = channel.queues
      queues_copy.clear

      expect(channel.queues).not_to be_empty
    end

    it "bindings returns a copy" do
      bindings_copy = channel.bindings
      bindings_copy.clear

      expect(channel.bindings).not_to be_empty
    end
  end

  describe "#bunny_channel" do
    it "raises RuntimeError when accessed" do
      expect { channel.bunny_channel }.to raise_error(
        RuntimeError,
        "Cannot access bunny_channel in mock mode. Mock mode is intended for testing only and cannot be used when running Harmoniser as a server process."
      )
    end
  end
end

RSpec.describe Harmoniser::Mock::Channel::MockExchange do
  let(:exchange_name) { "test_exchange" }
  let(:exchange_type) { "direct" }
  let(:exchange_opts) { {durable: true} }
  let(:full_opts) { {type: exchange_type}.merge(exchange_opts) }
  let(:exchange) { described_class.new(exchange_name, full_opts) }

  describe "#initialize" do
    it "sets attributes correctly" do
      expect(exchange.name).to eq(exchange_name)
      expect(exchange.type).to eq(exchange_type)
      expect(exchange.opts).to eq(exchange_opts)
    end

    it "initializes empty published messages" do
      expect(exchange.published_messages).to eq([])
    end
  end

  describe "#publish" do
    let(:payload) { "test message" }
    let(:publish_opts) { {routing_key: "test.key", mandatory: true} }

    it "records the published message and returns true" do
      result = exchange.publish(payload, publish_opts)

      expect(result).to be(true)
      expect(exchange.published_messages).to eq([{
        payload: payload,
        opts: publish_opts
      }])
    end

    it "records multiple published messages" do
      exchange.publish("message1", routing_key: "key1")
      exchange.publish("message2", routing_key: "key2")

      expect(exchange.published_messages.size).to eq(2)
      expect(exchange.published_messages[0]).to eq({
        payload: "message1",
        opts: {routing_key: "key1"}
      })
      expect(exchange.published_messages[1]).to eq({
        payload: "message2",
        opts: {routing_key: "key2"}
      })
    end

    it "handles publish with empty opts" do
      result = exchange.publish(payload)

      expect(result).to be(true)
      expect(exchange.published_messages).to eq([{
        payload: payload,
        opts: {}
      }])
    end
  end

  describe "#on_return" do
    it "stores the return handler block and returns self" do
      handler = proc { |basic_return, properties, payload| }
      result = exchange.on_return(&handler)

      expect(result).to be(exchange)
    end

    it "allows method chaining" do
      expect(exchange.on_return {}).to be(exchange)
    end
  end

  describe "#published_messages" do
    it "returns a copy of the messages array" do
      exchange.publish("test")
      messages_copy = exchange.published_messages
      messages_copy.clear

      expect(exchange.published_messages).not_to be_empty
    end
  end

  describe "#reset!" do
    before do
      exchange.publish("message1", routing_key: "key1")
      exchange.publish("message2", routing_key: "key2")
      exchange.on_return { |basic_return, properties, payload| }
    end

    it "clears all published messages" do
      expect(exchange.published_messages).not_to be_empty

      exchange.reset!

      expect(exchange.published_messages).to be_empty
    end

    it "resets the return handler to nil" do
      expect(exchange.instance_variable_get(:@return_handler)).not_to be_nil

      exchange.reset!

      expect(exchange.instance_variable_get(:@return_handler)).to be_nil
    end
  end
end

RSpec.describe Harmoniser::Mock::Channel::MockQueue do
  let(:queue_name) { "test_queue" }
  let(:queue_opts) { {durable: true, exclusive: false} }
  let(:queue) { described_class.new(queue_name, queue_opts) }

  describe "#initialize" do
    it "sets attributes correctly" do
      expect(queue.name).to eq(queue_name)
      expect(queue.opts).to eq(queue_opts)
    end
  end
end
