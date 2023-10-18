require "harmoniser/configuration"

RSpec.describe Harmoniser::Configuration do
  describe "#connection" do
    subject { described_class.new }

    before do
      subject.connection_opts = { host: "rabbitmq" }
    end

    it "creates a connection to RabbitMQ using Connection underneath" do
      expect_any_instance_of(Harmoniser::Connection).to receive(:start)

      subject.connection
    end

    it "connection creation is thread-safe" do
      connection_creation = lambda { subject.connection }

      result1 = Thread.new(&connection_creation)
      result2 = Thread.new(&connection_creation)

      expect(result1.value.object_id).to eq(result2.value.object_id)
    end

    it "each instance has its own connection" do
      configuration1 = described_class.new
      configuration1.connection_opts = { host: "rabbitmq" }
      configuration2 = described_class.new
      configuration2.connection_opts = { host: "rabbitmq" }

      expect(configuration1.connection.object_id).not_to eq(configuration2.connection.object_id)
    end

    it "a closed connection can be re-opened" do
      bunny_instance = subject.connection.instance_variable_get(:@bunny)
      subject.connection.close

      expect(bunny_instance.open?).to eq(false)
      expect(subject.connection.open?).to eq(true)
    end
  end

  describe "#connection_opts=" do
    subject { described_class.new }

    context "when called with empty opts" do
      it "uses default connection opts defined" do
        subject.connection_opts = {}

        expect(subject.connection_opts).to include({
          connection_name: /harmoniser@0.1.0-/,
          host: "127.0.0.1",
          logger: subject.logger,
          password: "guest",
          port: 5672,
          tls_silence_warnings: true,
          username: "guest",
          vhost: "/",
          verify_peer: false
        })
      end
    end

    context "when any argument matching properties of the default connection opts defined is passed" do
      it "override the properties" do
        subject.connection_opts = { host: "wadus", password: "secret_password" }

        expect(subject.connection_opts).to include({
          connection_name: /harmoniser@0.1.0-/,
          host: "wadus",
          logger: subject.logger,
          password: "secret_password",
          port: 5672,
          tls_silence_warnings: true,
          username: "guest",
          vhost: "/",
          verify_peer: false
        })
      end
    end

    context "when called without a non Hash object" do
      it "raises TypeError" do
        expect do
          subject.connection_opts = "wadus"
        end.to raise_error(TypeError, "opts must be a Hash object")
      end
    end
  end

  describe "define_topology" do
    it "yield a topology object" do
      expect do |b|
        subject.define_topology(&b)
      end.to yield_with_args(be_an_instance_of(Harmoniser::Topology))
    end

    it "topology object is memoized" do
      topology1 = nil
      topology2 = nil

      subject.define_topology { |topology| topology1 = topology }
      subject.define_topology { |topology| topology2 = topology }

      expect(topology1.object_id).to eq(topology2.object_id)
    end

    context "when block is not received" do
      it "raises LocalJumpError" do
        expect do
          subject.define_topology
        end.to raise_error(LocalJumpError, "A block is required for this method")
      end
    end
  end
end
