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
  end

  describe ".harmoniser_subscriber" do
    it "returns a Definition::Consumer with defaults" do
      result = klass.harmoniser_subscriber(queue_name: "a_queue")

      consumer_definition = Harmoniser::Definition::Consumer.new(queue_name: "a_queue", consumer_tag: nil, no_ack: true, exclusive: false, arguments: {})
      expect(result).to eq(consumer_definition)
    end

    it "returns a Definition::Consumer with values passed" do
      result = klass.harmoniser_subscriber(queue_name: "a_queue", consumer_tag: "a_consumer_tag", no_ack: false, exclusive: true, arguments: { foo: "bar" })

      consumer_definition = Harmoniser::Definition::Consumer.new(queue_name: "a_queue", consumer_tag: "a_consumer_tag", no_ack: false, exclusive: true, arguments: { foo: "bar" })
      expect(result).to eq(consumer_definition)
    end
  end

  describe ".on_delivery" do
    let(:exchange_name) { "harmoniser_publisher_exchange" }
    let(:queue_name) { "queue_harmoniser_publisher_exchange" }
    let(:klass) do
      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")

        class << self
          def consumed?
            @consumed
          end
        end
      end
    end
    before(:each) do
      channel = bunny.create_channel
      exchange = Bunny::Exchange.new(channel, :direct, exchange_name)
      Bunny::Queue.new(channel, queue_name).bind(exchange)
      exchange.publish("foo")
    end

    it "receive messages `on_delivery` method" do
      class << klass
        def on_delivery(delivery_info, properties, payload)
          @consumed = true
        end
      end

      klass.harmoniser_subscriber_start

      expect do
        require "timeout"
        Timeout.timeout(2) do
          until klass.consumed?; end
        end
      end.not_to raise_error
    end

    context "when klass does not respond to on_cancellation" do
      xit "uses default handler" do
        allow(Harmoniser.logger).to receive(:info)
        klass.harmoniser_subscriber_start

        expect(Harmoniser.logger).to have_received(:info).with(/default on_delivery handler executed/)
      end
    end
  end

  describe ".on_cancellation" do
    let(:exchange_name) { "harmoniser_publisher_exchange" }
    let(:queue_name) { "queue_harmoniser_publisher_exchange" }
    let(:klass) do
      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")
      end
    end
    let(:consumer) { klass.instance_variable_get(:@harmoniser_consumer) }
    before do
      channel = bunny.create_channel
      exchange = Bunny::Exchange.new(channel, :direct, exchange_name)
      Bunny::Queue.new(channel, queue_name).bind(exchange)
      exchange.publish("foo")
    end

    it "handle consumer cancellation" do
      class << klass
        def on_cancellation(basic_cancel)
          @called = true
        end
      end
      klass.harmoniser_subscriber_start
      basic_cancel = AMQ::Protocol::Basic::Cancel.new(consumer.consumer_tag, true)
      consumer.handle_cancellation(basic_cancel)

      result = klass.instance_variable_get(:@called)
      expect(result).to eq(true)
    end

    context "when klass does not respond to on_cancellation" do
      xit "uses default handler" do
        allow(Harmoniser.logger).to receive(:info)
        klass.harmoniser_subscriber_start
        basic_cancel = AMQ::Protocol::Basic::Cancel.new(consumer.consumer_tag, true)
        consumer.handle_cancellation(basic_cancel)

        expect(Harmoniser.logger).to have_received(:info).with(/default on_cancellation handler executed/)
      end
    end
  end
end
