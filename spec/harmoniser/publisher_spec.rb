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

    context "when Exchange definition is not provider" do
      before { klass.instance_variable_set(:@harmoniser_exchange_definition, nil) }

      it "raises MissingExchangeDefinition" do
        expect do
          klass.publish("foo")
        end.to raise_error(Harmoniser::Publisher::MissingExchangeDefinition, "Please, call harmoniser_publisher class method first with the exchange_name that will be used for publications")
      end
    end

    context "on_return" do
      # TODO handler for when a published message gets returned
    end

    context "serialisation" do
      # TODO decide whether or not seriliazers are introduced into this gem
    end

    context "handle errors" do
      # TODO handler for Channel#on_error as well as
      # Channel#on_uncaught_exception
    end
  end
end
