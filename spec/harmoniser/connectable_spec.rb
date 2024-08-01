require "harmoniser/connectable"

RSpec.describe Harmoniser::Connectable do
  let(:klass) do
    Class.new do
      include Harmoniser::Connectable
    end
  end
  let(:version) { Harmoniser::VERSION }
  subject { klass.new }

  describe "#connection_opts" do
    it "returns default connection opts" do
      expect(subject.connection_opts).to include({
        connection_name: "harmoniser@#{version}",
        connection_timeout: 5,
        host: "127.0.0.1",
        password: "guest",
        port: 5672,
        read_timeout: 5,
        tls_silence_warnings: true,
        username: "guest",
        verify_peer: false,
        vhost: "/",
        write_timeout: 5,
        logger: be_an_instance_of(Logger),
        recovery_attempt_started: be_a(Proc),
        recovery_completed: be_a(Proc)
      })
    end

    context "when new connection_opts are passed" do
      it "returns connection opts with overwritten opts" do
        subject.connection_opts = {connection_name: "wadus"}

        expect(subject.connection_opts).to include({
          connection_name: "wadus",
          host: "127.0.0.1",
          logger: be_an_instance_of(Logger),
          password: "guest",
          port: 5672,
          tls_silence_warnings: true,
          username: "guest",
          vhost: "/",
          verify_peer: false
        })
      end
    end
  end

  describe "#connection_opts=" do
    context "when called with empty opts" do
      it "uses default connection opts defined" do
        subject.connection_opts = {}

        expect(subject.connection_opts).to include({
          connection_name: "harmoniser@#{version}",
          host: "127.0.0.1",
          logger: be_an_instance_of(Logger),
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
        subject.connection_opts = {host: "wadus", password: "secret_password"}

        expect(subject.connection_opts).to include({
          connection_name: "harmoniser@#{version}",
          host: "wadus",
          logger: Harmoniser.logger,
          password: "secret_password",
          port: 5672,
          tls_silence_warnings: true,
          username: "guest",
          vhost: "/",
          verify_peer: false
        })
      end
    end

    context "when called with a non Hash object" do
      it "raises TypeError" do
        expect do
          subject.connection_opts = "wadus"
        end.to raise_error(TypeError, "opts must be a Hash object")
      end
    end
  end

  describe "#connection" do
    let(:host) { ENV.fetch("RABBITMQ_HOST") }

    before do
      subject.connection_opts = {host: host}
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

    it "a closed connection can be re-opened" do
      bunny_instance = subject.connection.instance_variable_get(:@bunny)
      subject.connection.close

      expect(bunny_instance.open?).to eq(false)
      expect(subject.connection.open?).to eq(true)
    end

    it "a closed connection due to a network failure CANNOT be re-opened" do
      bunny_instance = subject.connection.instance_variable_get(:@bunny)
      subject.connection.close
      bunny_instance.instance_variable_set(:@recovering_from_network_failure, true)

      expect(subject.connection.open?).to eq(false)
    end
  end

  describe ".connection?" do
    let(:host) { ENV.fetch("RABBITMQ_HOST") }
    before { subject.connection_opts = {host: host} }

    context "when connection is invoked" do
      it "returns true" do
        subject.connection

        expect(subject.connection?).to eq(true)
      end
    end

    it "returns false" do
      expect(subject.connection?).to eq(false)
    end
  end
end
