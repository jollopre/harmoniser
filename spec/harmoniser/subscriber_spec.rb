require "harmoniser/subscriber"
require "shared_context/configurable"

RSpec.describe Harmoniser::Subscriber do
  include_context "configurable"

  let(:klass) do
    Class.new do
      include Harmoniser::Subscriber
    end
  end

  context "private" do
    it "MUTEX constant is private" do
      expect do
        klass::MUTEX
      end.to raise_error(NameError, /private constant/)
    end

    describe ".on_delivery_instrumenter" do
      it "is private" do
        expect do
          klass.on_delivery_instrumenter
        end.to raise_error(NameError, /private method/)
      end
    end

    describe ".on_cancellation_instrumenter" do
      it "is private" do
        expect do
          klass.on_cancellation_instrumenter
        end.to raise_error(NameError, /private method/)
      end
    end
  end

  describe ".harmoniser_queue_declare" do
    after do
      bunny.with_channel do |channel|
        channel.queue_delete("a_queue")
      end
    end

    it "declare a queue" do
      klass.harmoniser_queue_declare("a_queue", {})

      result = bunny.queue_exists?("a_queue")
      expect(result).to eq(true)
    end
  end

  describe ".harmoniser_queue_bind" do
    let(:name) { "a_queue" }
    let(:exchange_name) { "a_exchange" }
    before do
      bunny.start
      bunny.with_channel do |channel|
        channel.queue_declare(name)
        channel.exchange_declare(exchange_name, :fanout)
      end
    end

    after do
      bunny.with_channel do |channel|
        channel.queue_delete(name)
        channel.exchange_delete(exchange_name)
      end
    end

    it "bind a queue to an exchange" do
      result = klass.harmoniser_queue_bind(name, exchange_name, {})

      expect(result).to be_an_instance_of(AMQ::Protocol::Queue::BindOk)
    end

    context "when the exchange is not found" do
      it "raise error" do
        skip("todo")
      end
    end
  end

  describe ".harmoniser_subscriber" do
    it "return a Bunny::Consumer" do
      result = klass.harmoniser_subscriber(queue: "a_queue")

      expect(result).to be_an_instance_of(Bunny::Consumer)
    end

    context "when block is given" do
      it "yield a Bunny::Consumer for setting advance configuration" do
        expect do |b|
          klass.harmoniser_subscriber(queue: "a_queue", &b)
        end.to yield_with_args(be_an_instance_of(Bunny::Consumer))
      end
    end

    it "subscription is thread-safe" do
      subscription = lambda { klass.harmoniser_subscriber(queue: "a_queue") }

      result1 = Thread.new(&subscription)
      result2 = Thread.new(&subscription)

      expect(result1.value.object_id).to eq(result2.value.object_id)
    end

    context "when two different queues are used for subscribing" do
      it "first declaration is chosen" do
        result1 = klass.harmoniser_subscriber(queue: "a_queue")
        result2 = klass.harmoniser_subscriber(queue: "a_queue")

        expect(result1.queue).to eq("a_queue")
        expect(result2.queue).to eq("a_queue")
      end
    end
  end

  describe ".on_delivery" do
    let(:klass) do
      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber(queue: "a_queue")

        class << self
          def consumed?
            @consumed
          end
        end
      end
    end
    let(:consumer) { klass.harmoniser_consumer }
    before(:each) do
      exchange = consumer.channel.fanout("an_exchange")
      consumer.channel.queue("a_queue", auto_delete: true).bind(exchange)
      exchange.publish("foo")
    end

    it "receive messages `on_delivery` method" do
      class << klass
        def on_delivery(delivery_info, properties, payload)
          @consumed = true
        end
      end

      expect do
        require "timeout"
        Timeout.timeout(2) do
          until klass.consumed?; end
        end
      end.not_to raise_error
    end
  end

  describe ".on_cancellation" do
    let(:klass) do
      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber(queue: "a_queue")
      end
    end
    let(:consumer) { klass.harmoniser_consumer }

    it "handle consumer cancellation" do
      class << klass
        def on_cancellation(basic_cancel)
          @called = true
        end
      end

      basic_cancel = AMQ::Protocol::Basic::Cancel.new(consumer.consumer_tag, true)
      consumer.handle_cancellation(basic_cancel)

      result = klass.instance_variable_get(:@called)
      expect(result).to eq(true)
    end
  end
end
