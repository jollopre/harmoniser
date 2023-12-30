require "harmoniser/subscriber"
require "shared_context/configurable"

RSpec.describe Harmoniser::Subscriber do
  include_context "configurable"

  describe ".harmoniser_subscriber" do
    let(:klass) do
      Class.new do
        include Harmoniser::Subscriber
      end
    end

    it "returns a Definition::Consumer with defaults" do
      result = klass.harmoniser_subscriber(queue_name: "a_queue")

      consumer_definition = Harmoniser::Definition::Consumer.new(queue_name: "a_queue", consumer_tag: nil, no_ack: true, exclusive: false, arguments: {})
      expect(result).to eq(consumer_definition)
    end

    it "returns a Definition::Consumer with values passed" do
      result = klass.harmoniser_subscriber(queue_name: "a_queue", consumer_tag: "a_consumer_tag", no_ack: false, exclusive: true, arguments: {foo: "bar"})

      consumer_definition = Harmoniser::Definition::Consumer.new(queue_name: "a_queue", consumer_tag: "a_consumer_tag", no_ack: false, exclusive: true, arguments: {foo: "bar"})
      expect(result).to eq(consumer_definition)
    end
  end

  describe ".harmoniser_subscriber_start" do
    context "when Consumer definition is not provided" do
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
        end
      end

      it "raises MissingConsumerDefinition" do
        expect do
          klass.harmoniser_subscriber_start
        end.to raise_error(Harmoniser::Subscriber::MissingConsumerDefinition, /Please, call harmoniser_subscriber class method first/)
      end
    end

    context "when Consumer definition is provided" do
      let(:exchange_name) { "harmoniser_publisher_exchange" }
      let(:queue_name) { "queue_harmoniser_publisher_exchange" }
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")
        end
      end
      let(:another_klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")
        end
      end
      before(:each) do
        declare_exchange(exchange_name)
        declare_queue(queue_name, exchange_name)
      end

      it "creates a Consumer" do
        result = klass.harmoniser_subscriber_start

        expect(result).to be_an_instance_of(Bunny::Consumer)
        result.cancel
      end

      it "channel is dedicated for each subscriber" do
        consumer = klass.harmoniser_subscriber_start
        another_consumer = another_klass.harmoniser_subscriber_start

        expect(consumer.channel).not_to eq(another_consumer.channel)
        consumer.cancel
        another_consumer.cancel
      end
    end
  end

  describe ".on_delivery" do
    let(:exchange_name) { "harmoniser_publisher_exchange" }
    let(:queue_name) { "queue_harmoniser_publisher_exchange" }
    let!(:exchange) { declare_exchange(exchange_name) }
    let!(:queue) { declare_queue(queue_name, exchange.name) }

    context "when klass respond to on_delivery" do
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")

          class << self
            def consumed?
              @consumed
            end

            def on_delivery(delivery_info, properties, payload)
              @consumed = true
            end
          end
        end
      end

      it "receive messages `on_delivery` method" do
        exchange.publish("foo")

        klass.harmoniser_subscriber_start

        expect do
          require "timeout"
          Timeout.timeout(2) do
            until klass.consumed?; end
          end
        end.not_to raise_error
      end
    end

    context "when klass does not respond to on_delivery" do
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")
        end
      end

      it "uses default handler which output to stdout" do
        exchange.publish("foo")

        consumer = klass.harmoniser_subscriber_start

        expect do
          consumer.call
        end.to output(/INFO -- .*Default on_delivery handler executed for consumer: consumer_tag = `#{consumer.consumer_tag}`, queue = `#{consumer.queue}`/).to_stdout_from_any_process
      end
    end
  end

  describe ".on_cancellation" do
    let(:exchange_name) { "harmoniser_publisher_exchange" }
    let(:queue_name) { "queue_harmoniser_publisher_exchange" }

    before do
      declare_exchange(exchange_name)
      declare_queue(queue_name, exchange_name)
    end

    context "when klass respond to on_cancellation" do
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")

          class << self
            def on_cancellation(basic_cancel)
              @called = true
            end
          end
        end
      end

      it "handle consumer cancellation" do
        consumer = klass.harmoniser_subscriber_start
        basic_cancel = AMQ::Protocol::Basic::Cancel.new(consumer.consumer_tag, true)
        consumer.handle_cancellation(basic_cancel)

        result = klass.instance_variable_get(:@called)
        expect(result).to eq(true)
      end
    end

    context "when klass does not respond to on_cancellation" do
      let(:klass) do
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber(queue_name: "queue_harmoniser_publisher_exchange")
        end
      end

      it "uses default handler which output to stdout" do
        consumer = klass.harmoniser_subscriber_start
        basic_cancel = AMQ::Protocol::Basic::Cancel.new(consumer.consumer_tag, true)

        expect do
          consumer.handle_cancellation(basic_cancel)
        end.to output(/INFO -- .*Default on_cancellation handler executed for consumer: consumer_tag = `#{basic_cancel.consumer_tag}`, queue = `#{consumer.queue}`/).to_stdout_from_any_process
      end
    end
  end
end
