# frozen_string_literal: true

require "harmoniser/mock"
require "harmoniser/publisher"
require "harmoniser/topology"
require "shared_context/configurable"

RSpec.describe Harmoniser::Mock do
  include_context "configurable"

  # Reset state before each test to ensure clean state
  before do
    described_class.instance_variable_set(:@mocked, false)
    described_class.instance_variable_set(:@prepended, false)

    # Clear any existing connections to ensure clean state
    clear_connections
  end

  # Clean up after each test
  after do
    described_class.disable! if described_class.mocked?
    clear_connections
  end

  def clear_connections
    # Clear Publisher connections
    begin
      Harmoniser::Publisher.remove_instance_variable(:@connection)
    rescue
      nil
    end
    begin
      Harmoniser::Publisher.remove_instance_variable(:@mock_connection)
    rescue
      nil
    end

    # Clear Topology connections
    begin
      Harmoniser::Topology.remove_instance_variable(:@connection)
    rescue
      nil
    end
    begin
      Harmoniser::Topology.remove_instance_variable(:@mock_connection)
    rescue
      nil
    end
  end

  describe ".mock!" do
    it "enables mocking" do
      expect { described_class.mock! }.to change { described_class.mocked? }.from(false).to(true)
    end

    it "prepends MockConnectableMethods to Harmoniser::Connectable::ClassMethods" do
      described_class.mock!

      expect(Harmoniser::Connectable::ClassMethods.ancestors).to include(Harmoniser::Mock::MockConnectableMethods)
    end

    it "only prepends once even when called multiple times" do
      # Call mock! multiple times
      described_class.mock!
      described_class.mock!
      described_class.mock!

      # Count how many times MockConnectableMethods appears in ancestors
      mock_module_count = Harmoniser::Connectable::ClassMethods.ancestors.count do |mod|
        mod == Harmoniser::Mock::MockConnectableMethods
      end

      expect(mock_module_count).to eq(1)
    end

    it "sets @prepended flag to true" do
      described_class.mock!

      expect(described_class.instance_variable_get(:@prepended)).to be(true)
    end

    it "maintains @prepended flag as true on subsequent calls" do
      described_class.mock!
      first_prepended_state = described_class.instance_variable_get(:@prepended)

      described_class.mock!
      second_prepended_state = described_class.instance_variable_get(:@prepended)

      expect(first_prepended_state).to be(true)
      expect(second_prepended_state).to be(true)
    end
  end

  describe ".disable!" do
    it "disables mocking" do
      described_class.mock!

      expect { described_class.disable! }.to change { described_class.mocked? }.from(true).to(false)
    end

    it "can be called when already disabled" do
      expect(described_class.mocked?).to be(false)

      expect { described_class.disable! }.not_to raise_error
      expect(described_class.mocked?).to be(false)
    end

    it "does not remove prepended module" do
      described_class.mock!
      expect(Harmoniser::Connectable::ClassMethods.ancestors).to include(Harmoniser::Mock::MockConnectableMethods)

      described_class.disable!

      # Module remains prepended but behavior changes based on mocked? state
      expect(Harmoniser::Connectable::ClassMethods.ancestors).to include(Harmoniser::Mock::MockConnectableMethods)
    end
  end

  describe ".mocked?" do
    it "returns false by default" do
      expect(described_class.mocked?).to be(false)
    end

    it "returns true after mock! is called" do
      described_class.mock!

      expect(described_class.mocked?).to be(true)
    end

    it "returns false after disable! is called" do
      described_class.mock!
      described_class.disable!

      expect(described_class.mocked?).to be(false)
    end
  end

  describe ".disabled?" do
    it "returns true by default" do
      expect(described_class.disabled?).to be(true)
    end

    it "returns false after mock! is called" do
      described_class.mock!

      expect(described_class.disabled?).to be(false)
    end

    it "returns true after disable! is called" do
      described_class.mock!
      described_class.disable!

      expect(described_class.disabled?).to be(true)
    end

    it "is always the opposite of mocked?" do
      # Default state
      expect(described_class.disabled?).to eq(!described_class.mocked?)

      # After enabling
      described_class.mock!
      expect(described_class.disabled?).to eq(!described_class.mocked?)

      # After disabling
      described_class.disable!
      expect(described_class.disabled?).to eq(!described_class.mocked?)
    end
  end

  describe "MockConnectableMethods" do
    describe "#connection" do
      context "when mocking is enabled" do
        before { described_class.mock! }

        it "returns a Mock::Connection instance for Publisher" do
          connection = Harmoniser::Publisher.connection

          expect(connection).to be_a(Harmoniser::Mock::Connection)
        end

        it "returns a Mock::Connection instance for Topology" do
          connection = Harmoniser::Topology.connection

          expect(connection).to be_a(Harmoniser::Mock::Connection)
        end

        it "returns the same connection instance on subsequent calls" do
          connection1 = Harmoniser::Publisher.connection
          connection2 = Harmoniser::Publisher.connection

          expect(connection1).to be(connection2)
        end

        it "does not interact with real RabbitMQ" do
          # Ensure no real RabbitMQ connections are attempted
          expect(Bunny).not_to receive(:new)

          connection = Harmoniser::Publisher.connection
          expect(connection).to be_a(Harmoniser::Mock::Connection)
        end

        it "uses Harmoniser.configuration" do
          # Should not raise error about missing configuration
          expect { Harmoniser::Publisher.connection }.not_to raise_error
        end
      end

      context "when mocking is disabled" do
        before { described_class.disable! }

        it "calls super (real connection behavior)" do
          expect(Harmoniser::Publisher.connection).to be_an_instance_of(Harmoniser::Connection)
        end
      end
    end

    describe "#connection?" do
      context "when mocking is enabled" do
        before { described_class.mock! }

        it "returns false when no connection has been created" do
          expect(Harmoniser::Publisher.connection?).to be(false)
        end

        it "returns true when connection has been created" do
          Harmoniser::Publisher.connection

          expect(Harmoniser::Publisher.connection?).to be(true)
        end
      end

      context "when mocking is disabled" do
        before { described_class.disable! }

        it "calls super (real connection? behavior)" do
          # Since we prepended the module, super would be the original Connectable method
          expect(Harmoniser::Publisher.connection?).to be(false)
        end
      end
    end

    describe "#create_channel" do
      context "when mocking is enabled" do
        before { described_class.mock! }

        it "creates a mock channel for Publisher" do
          channel = Harmoniser::Publisher.create_channel
          expect(channel).to be_a(Harmoniser::Mock::Channel)
        end

        it "creates a mock channel for Topology" do
          channel = Harmoniser::Topology.create_channel
          expect(channel).to be_a(Harmoniser::Mock::Channel)
        end

        it "passes custom parameters without error" do
          # Test that custom parameters don't cause errors
          expect do
            Harmoniser::Publisher.create_channel(
              consumer_pool_size: 5,
              consumer_pool_shutdown_timeout: 120
            )
          end.not_to raise_error
        end

        it "does not interact with real RabbitMQ channels" do
          # Should not attempt to create real channels
          expect(Bunny::Channel).not_to receive(:new)

          channel = Harmoniser::Publisher.create_channel
          expect(channel).to be_a(Harmoniser::Mock::Channel)
        end
      end

      context "when mocking is disabled" do
        before { described_class.disable! }

        it "calls super (real create_channel behavior)" do
          expect(Harmoniser::Publisher.create_channel).to be_an_instance_of(Harmoniser::Channel)
        end
      end
    end
  end

  describe "Publisher integration" do
    context "when mocking is enabled" do
      before { described_class.mock! }

      it "Publisher uses mock connection" do
        connection = Harmoniser::Publisher.connection
        expect(connection).to be_a(Harmoniser::Mock::Connection)
      end

      it "Publisher uses mock channel" do
        channel = Harmoniser::Publisher.create_channel
        expect(channel).to be_a(Harmoniser::Mock::Channel)
      end

      it "Publisher connection? works correctly" do
        expect(Harmoniser::Publisher.connection?).to be(false)
        Harmoniser::Publisher.connection
        expect(Harmoniser::Publisher.connection?).to be(true)
      end

      it "captures published messages in mock exchange" do
        # Create a test class that includes Publisher
        test_publisher_class = Class.new do
          include Harmoniser::Publisher
          harmoniser_publisher(exchange_name: "test_exchange")
        end

        # Publish a test message
        payload = {message: "test message", id: 123}
        opts = {routing_key: "test.key", mandatory: true}

        exchange = test_publisher_class.publish(payload, opts)

        # Verify the exchange is a mock and captured the message
        expect(exchange).to be_a(Harmoniser::Mock::Channel::MockExchange)
        expect(exchange.name).to eq("test_exchange")
        expect(exchange.published_messages).to eq([{
          payload: payload,
          opts: opts
        }])
      end
    end

    context "when mocking is disabled" do
      before { described_class.disable! }

      it "Publisher attempts real connection and fails" do
        expect(Harmoniser::Publisher.connection).to be_an_instance_of(Harmoniser::Connection)
      end
    end
  end

  describe "Topology integration" do
    context "when mocking is enabled" do
      before { described_class.mock! }

      it "Topology uses mock connection" do
        connection = Harmoniser::Topology.connection
        expect(connection).to be_a(Harmoniser::Mock::Connection)
      end

      it "Topology uses mock channel" do
        channel = Harmoniser::Topology.create_channel
        expect(channel).to be_a(Harmoniser::Mock::Channel)
      end

      it "Topology connection? works correctly" do
        expect(Harmoniser::Topology.connection?).to be(false)
        Harmoniser::Topology.connection
        expect(Harmoniser::Topology.connection?).to be(true)
      end

      it "Topology instance can use class methods" do
        topology = Harmoniser::Topology.new
        connection = topology.class.connection
        expect(connection).to be_a(Harmoniser::Mock::Connection)
      end

      it "captures topology declarations in declared channel" do
        topology = Harmoniser::Topology.new

        # Add exchanges, queues, and bindings to topology
        topology.add_exchange("direct", "orders_exchange", durable: true, auto_delete: false)
        topology.add_exchange("fanout", "notifications_exchange")
        topology.add_queue("orders_queue", durable: true, exclusive: false)
        topology.add_queue("notifications_queue")
        topology.add_binding("orders_exchange", "orders_queue", routing_key: "order.created")
        topology.add_binding("notifications_exchange", "notifications_queue")

        # Declare the topology - this creates the channel and performs declarations
        topology.declare

        # Access the channel that was used for declaration
        channel = topology.declared_channel
        expect(channel).to be_a(Harmoniser::Mock::Channel)

        # Verify exchanges were declared on the channel
        exchanges = channel.exchanges
        expect(exchanges.keys).to include("orders_exchange", "notifications_exchange")

        orders_exchange = exchanges["orders_exchange"]
        expect(orders_exchange.name).to eq("orders_exchange")
        expect(orders_exchange.type).to eq("direct")
        expect(orders_exchange.opts).to eq({durable: true, auto_delete: false})

        notifications_exchange = exchanges["notifications_exchange"]
        expect(notifications_exchange.name).to eq("notifications_exchange")
        expect(notifications_exchange.type).to eq("fanout")
        expect(notifications_exchange.opts).to eq({})

        # Verify queues were declared on the channel
        queues = channel.queues
        expect(queues.keys).to include("orders_queue", "notifications_queue")

        orders_queue = queues["orders_queue"]
        expect(orders_queue.name).to eq("orders_queue")
        expect(orders_queue.opts).to eq({durable: true, exclusive: false})

        notifications_queue = queues["notifications_queue"]
        expect(notifications_queue.name).to eq("notifications_queue")
        expect(notifications_queue.opts).to eq({})

        # Verify bindings were declared on the channel
        bindings = channel.bindings
        expect(bindings).to include({
          destination_name: "orders_queue",
          exchange_name: "orders_exchange",
          opts: {routing_key: "order.created"}
        })
        expect(bindings).to include({
          destination_name: "notifications_queue",
          exchange_name: "notifications_exchange",
          opts: {}
        })
      end
    end

    context "when mocking is disabled" do
      before { described_class.disable! }

      it "Topology attempts real connection" do
        expect(Harmoniser::Topology.connection).to be_an_instance_of(Harmoniser::Connection)
      end
    end
  end

  describe "thread safety" do
    it "mock state changes are thread-safe" do
      threads = 10.times.map do
        Thread.new do
          described_class.mock!
          sleep(0.001) # Small delay to increase chance of race conditions
          described_class.disable!
        end
      end

      threads.each(&:join)

      # Should end in a consistent state
      expect(described_class.disabled?).to be(true)
    end

    it "prepending only happens once even with concurrent calls" do
      threads = 5.times.map do
        Thread.new { described_class.mock! }
      end

      threads.each(&:join)

      # Count how many times MockConnectableMethods appears in ancestors
      mock_module_count = Harmoniser::Connectable::ClassMethods.ancestors.count do |mod|
        mod == Harmoniser::Mock::MockConnectableMethods
      end

      expect(mock_module_count).to eq(1)
    end
  end

  describe "state persistence" do
    it "maintains mocked state across multiple operations" do
      described_class.mock!
      expect(described_class.mocked?).to be(true)

      # Perform some operations with Publisher
      connection = Harmoniser::Publisher.connection
      channel = Harmoniser::Publisher.create_channel

      # Verify the operations worked with mocks
      expect(connection).to be_a(Harmoniser::Mock::Connection)
      expect(channel).to be_a(Harmoniser::Mock::Channel)

      # State should remain consistent
      expect(described_class.mocked?).to be(true)
      expect(described_class.disabled?).to be(false)
    end
  end

  describe "real vs mock behavior" do
    it "switches between real and mock behavior correctly" do
      # Start disabled - should attempt real connection
      expect(Harmoniser::Publisher.connection).to be_an_instance_of(Harmoniser::Connection)

      # Enable mock - should use mock connection
      described_class.mock!
      connection = Harmoniser::Publisher.connection
      expect(connection).to be_a(Harmoniser::Mock::Connection)

      # Disable mock - should attempt real connection again
      described_class.disable!

      expect(Harmoniser::Publisher.connection).to be_an_instance_of(Harmoniser::Connection)
    end
  end
end
