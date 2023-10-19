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

  it "MUTEX constant is private" do
    expect do
      klass::MUTEX
    end.to raise_error(NameError, /private constant/)
  end

  describe ".harmoniser_publisher" do
    it "return a Definition::Exchange" do
      result = klass.harmoniser_publisher(exchange_name: exchange_name)

      exchange_definition = Harmoniser::Definition::Exchange.new(name: exchange_name, type: nil, opts: { passive: true })
      expect(result).to eq(exchange_definition)
    end
  end

  describe ".publish" do
    before do
      channel = bunny.create_channel
      exchange = Bunny::Exchange.new(channel, :direct, exchange_name)
      queue = Bunny::Queue.new(channel).bind(exchange)
      queue.subscribe do |_,_,_|
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

    it "channel is shared across publications" do
      result1 = klass.publish("foo").channel
      result2 = klass.publish("bar").channel

      expect(result1.object_id).to eq(result2.object_id)
    end

    context "when exchange does not exist" do
      it "raises Bunny::NotFound" do
        klass.harmoniser_publisher(exchange_name: "wtf")

        expect do
          klass.publish("foo")
        end.to raise_error(Bunny::NotFound)
      end
    end

    context "when exchange definition is not provider" do
      before { klass.instance_variable_set(:@harmoniser_exchange_definition, nil) }

      it "raises MissingExchangeDefinition" do
        expect do
          klass.publish("foo")
        end.to raise_error(Harmoniser::Publisher::MissingExchangeDefinition, "Please, call harmoniser_publisher class method first with the exchange_name that will be used for publications")
      end
    end

    context "on_return" do
      # TODO
    end

    context "serialisation" do
      # TODO
    end

    context "handle errors" do
      # TODO
    end

    context "handle OS signals" do
      # TODO
    end
  end
end
