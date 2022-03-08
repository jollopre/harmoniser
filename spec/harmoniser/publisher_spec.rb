require "harmoniser/publisher"
require "shared_context/configurable"

RSpec.describe Harmoniser::Publisher do
  include_context "configurable"

  let(:klass) do
    Class.new do
      include Harmoniser::Publisher
    end
  end

  it "MUTEX constant is private" do
    expect do
      klass::MUTEX
    end.to raise_error(NameError, /private constant/)
  end

  describe ".harmoniser_publisher" do
    it "return a Bunny::Exchange" do
      result = klass.harmoniser_publisher(name: "an_exchange_name")

      expect(result).to be_an_instance_of(Bunny::Exchange)
    end

    context "when block is given" do
      it "yield a Bunny::Exchange for setting advance configuration" do
        expect do |b|
          klass.harmoniser_publisher(name: "an_exchange_name", &b)
        end.to yield_with_args(be_an_instance_of(Bunny::Exchange))
      end
    end

    it "exchange declaration is thread-safe" do
      exchange_declaration = lambda { klass.harmoniser_publisher(name: "an_exchange_name") }

      result1 = Thread.new(&exchange_declaration)
      result2 = Thread.new(&exchange_declaration)

      expect(result1.value.object_id).to eq(result2.value.object_id)
    end

    context "when two different name are declared for the same publisher" do
      it "first declaration is chosen" do
        result1 = klass.harmoniser_publisher(name: "an_exchange_name")
        result2 = klass.harmoniser_publisher(name: "another_exchange_name")

        expect(result1.name).to eq("an_exchange_name")
        expect(result2.name).to eq("an_exchange_name")
      end
    end
  end

  describe ".publish" do
    let!(:exchange) do
      klass.harmoniser_publisher(name: "exchange") do |exchange|
        queue = exchange.channel.queue("", auto_delete: true).bind(exchange)
        @consumed = false
        queue.subscribe do |delivery_info, properties, payload|
          @consumed = true
        end
      end
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

    it "publication is thread-safe" do
      exchange_publication = lambda { klass.publish("foo") }
      result1 = Thread.new(&exchange_publication)
      result2 = Thread.new(&exchange_publication)

      expect do
        result1.value
        result2.value
      end.not_to raise_error(Bunny::Exception)
    end

    context "declare exchange with defaults" do
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
