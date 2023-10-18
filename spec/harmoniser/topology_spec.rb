require "harmoniser/topology"
require "shared_context/configurable"
require "shared_context/rabbitmq_management"

RSpec.describe Harmoniser::Topology do
  subject { described_class.new }

  describe "#add_exchange" do
    it "adds exchange to the topology" do
      subject.add_exchange(:fanout, "an_exchange", durable: false, arguments: {})

      expect(subject.exchanges).to include(
        Harmoniser::Topology::Exchange.new(
          name: "an_exchange",
          type: :fanout,
          opts: { durable: false, arguments: {} }
        )
      )
    end

    context "when exchange already exist defined in the topology" do
      it "does not add it" do
        subject.add_exchange(:fanout, "an_exchange")
        subject.add_exchange(:topic, "an_exchange")

        expected_exchanges = Set.new([
          Harmoniser::Topology::Exchange.new(
            type: :fanout,
            name: "an_exchange",
            opts: {}
          )
        ])
        expect(subject.exchanges).to match(expected_exchanges)
      end
    end

    context "when opts are not passed" do
      it "adds exchange to the topology with empty opts" do
        subject.add_exchange(:fanout, "an_exchange")

        expect(subject.exchanges).to include(
          Harmoniser::Topology::Exchange.new(
            name: "an_exchange",
            type: :fanout,
            opts: {}
          )
        )
      end
    end
  end
  
  describe "#add_queue" do
    it "adds queue to the topology" do
      subject.add_queue("a_queue", durable: false, type: "classic")

      expect(subject.queues).to include(
        Harmoniser::Topology::Queue.new(
          name: "a_queue",
          opts: { durable: false, type: "classic" }
        )
      )
    end

    context "when queue already exist defined in the topology" do
      it "does not add it" do
        subject.add_queue("a_queue")
        subject.add_queue("a_queue")

        expected_queues = Set.new([
          Harmoniser::Topology::Queue.new(
            name: "a_queue",
            opts: {}
          )
        ])
        expect(subject.queues).to match(expected_queues)
      end
    end

    context "when opts are not passed" do
      it "adds queue to the topology with empty opts" do
        subject.add_queue("a_queue")

        expect(subject.queues).to include(
          Harmoniser::Topology::Queue.new(
            name: "a_queue",
            opts: {}
          )
        )
      end
    end
  end

  describe "#add_binding" do
    it "adds binding of a queue to an exchange" do
      subject.add_binding("a_exchange", "a_queue", :queue, routing_key: "wadus")

      expect(subject.bindings).to include(
        Harmoniser::Topology::Binding.new(
          exchange_name: "a_exchange",
          destination_name: "a_queue",
          destination_type: :queue,
          opts: { routing_key: "wadus" }
        )
      )
    end

    it "adds binding of a exchange to another exchange" do
      subject.add_binding("a_exchange", "another_exchange", :exchange, routing_key: "wadus")

      expect(subject.bindings).to include(
        Harmoniser::Topology::Binding.new(
          exchange_name: "a_exchange",
          destination_name: "another_exchange",
          destination_type: :exchange,
          opts: { routing_key: "wadus" }
        )
      )
    end

    it "accepts duplicate bindings" do
      subject.add_binding("a_exchange", "a_queue", :queue, routing_key: "wadus")
      subject.add_binding("a_exchange", "a_queue", :queue, routing_key: "wadus")

      expect(subject.bindings).to eq(Set.new([
        Harmoniser::Topology::Binding.new(
          exchange_name: "a_exchange",
          destination_name: "a_queue",
          destination_type: :queue,
          opts: { routing_key: "wadus" }
        ),
        Harmoniser::Topology::Binding.new(
          exchange_name: "a_exchange",
          destination_name: "a_queue",
          destination_type: :queue,
          opts: { routing_key: "wadus" }
        )
      ]))
    end

    context "when destination_type is missing" do
      it "defaults to `queue`" do
        subject.add_binding("a_exchange", "a_queue", routing_key: "wadus")

        expect(subject.bindings).to include(
          Harmoniser::Topology::Binding.new(
            exchange_name: "a_exchange",
            destination_name: "a_queue",
            destination_type: :queue,
            opts: { routing_key: "wadus" }
          )
        )
      end
    end

    context "when opts are not passed" do
      it "adds binding to the topology with empty opts" do
        subject.add_binding("a_exchange", "a_queue", :queue)

        expect(subject.bindings).to include(
          Harmoniser::Topology::Binding.new(
            exchange_name: "a_exchange",
            destination_name: "a_queue",
            destination_type: :queue,
            opts: {}
          )
        )
      end
    end
  end

  describe "#declare" do
    include_context "configurable"
    include_context "rabbitMQ management"

    context "broadcast routing" do
      subject { described_class.new }

      it "creates a fanout exchange and a couple of queues bound to it" do
        subject.add_exchange(:fanout, "broadcast_exchange")
        subject.add_queue("queue_broadcast_exchange")
        subject.add_queue("another_queue_broadcast_exchange")
        subject.add_binding("broadcast_exchange", "queue_broadcast_exchange")
        subject.add_binding("broadcast_exchange", "another_queue_broadcast_exchange")

        subject.declare

        definitions = get_definitions
        expect(definitions).to include(
          exchanges: include(
            hash_including(
              name: "broadcast_exchange",
              vhost: "/",
              type: "fanout",
              durable: false,
              auto_delete: false,
              internal: false,
              arguments: {}
            )
          )
        )
      end
    end

    xcontext "unicast routing" do
      subject { described_class.new }

      it "creates a direct exchange and a couple of queues with different routing key" do
        subject.add_exchange(:direct, "unicast_exchange")
        subject.add_queue("queue1_unicast_exchange")
        subject.add_queue("queue2_unicast_exchange")
        subject.add_binding("unicast_exchange", "queue1_unicast_exchange", routing_key: "queue1")
        subject.add_binding("unicast_exchange", "queue2_unicast_exchange", routing_key: "queue2")

        subject.declare
      end
    end

    xcontext "multicast routing" do
      subject { described_class.new }

      it "creates a topic exchange and a couple of queues with different routing key" do
        subject.add_exchange(:topic, "multicast_exchange")
        subject.add_queue("queue1_multicast_exchange")
        subject.add_queue("queue2_multicast_exchange")
        subject.add_binding("multicast_exchange", "queue1_multicast_exchange", routing_key: "foo.#")
        subject.add_binding("multicast_exchange", "queue2_multicast_exchange", routing_key: "foo.*")

        subject.declare
      end
    end
  end
end
