require "harmoniser/publisher"
require "shared_context/configurable"

RSpec.describe Harmoniser::Publisher do
  include_context "configurable"

  let(:klass) do
    Class.new do
      include Harmoniser::Publisher
    end
  end
  let(:exchange_name) { "harmoniser_publisher_exchange" }

  describe ".harmoniser_publisher" do
    it "return a Definition::Exchange" do
      result = klass.harmoniser_publisher(exchange_name: exchange_name)

      exchange_definition = Harmoniser::Definition::Exchange.new(name: exchange_name, type: nil, opts: {passive: true})
      expect(result).to eq(exchange_definition)
    end
  end

  describe ".publish" do
    before do
      declare_exchange(exchange_name)
      declare_queue("", exchange_name).subscribe do |_, _, _|
        @consumed = true
      end
      klass.harmoniser_publisher(exchange_name: exchange_name)
    end

    it "publish a message" do
      klass.publish("foo")

      expect do
        require "timeout"
        Timeout.timeout(2) do
          until @consumed; end
        end
      end.not_to raise_error
    end

    it "channel is shared across publisher publications" do
      result1 = klass.publish("foo").channel
      result2 = klass.publish("bar").channel

      expect(result1.object_id).to eq(result2.object_id)
    end

    it "channel is dedicated to each publisher" do
      another_klass = Class.new { include Harmoniser::Publisher }
      another_klass.harmoniser_publisher(exchange_name: exchange_name)
      exchange = klass.publish("foo")
      another_exchange = another_klass.publish("foo")

      expect(exchange.channel).not_to eq(another_exchange.channel)
    end

    context "when verbose mode is set" do
      before do
        Harmoniser.configure { |config| config.options_with(verbose: true) }
      end
      after do
        Harmoniser.configure { |config| config.options_with(verbose: false) }
      end

      it "logs the message published" do
        expect do
          klass.publish("foo")
        end.to output(/DEBUG -- .*Message published/).to_stdout_from_any_process
      end
    end

    context "when exchange does not exist" do
      it "raises Bunny::NotFound" do
        klass.harmoniser_publisher(exchange_name: "wtf")

        expect do
          klass.publish("foo")
        end.to raise_error(Bunny::NotFound)
      end
    end

    context "when Exchange definition is not provided" do
      before { klass.instance_variable_set(:@harmoniser_exchange_definition, nil) }

      it "raises MissingExchangeDefinition" do
        expect do
          klass.publish("foo")
        end.to raise_error(Harmoniser::Publisher::MissingExchangeDefinition, /Please call the harmoniser_publisher class method at/)
      end
    end

    context "when a mandatory message cannot be routed" do
      let(:klass) do
        Class.new do
          include Harmoniser::Publisher
        end
      end

      before do
        declare_exchange("exchange_without_queues")
        klass.harmoniser_publisher(exchange_name: "exchange_without_queues")
      end

      it "log with warn severity is output" do
        expect do
          klass.publish("foo", mandatory: true)
          # TODO find a better way to test this since AMQ::Protocol::Basic::Return comes async after the publication is completed
          sleep 0.2
        end.to output(/WARN -- .*Default on_return handler executed for exchange/).to_stdout_from_any_process
      end
    end
  end

  context "connectable" do
    it "responds to .connection" do
      expect(described_class).to respond_to(:connection)
    end

    it "responds to .connection" do
      expect(described_class).to respond_to(:connection?)
    end

    it "responds to .connection" do
      expect(described_class).to respond_to(:create_channel)
    end
  end
end
