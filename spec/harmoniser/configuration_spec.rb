require "harmoniser/configuration"

RSpec.describe Harmoniser::Configuration do
  describe "#connection" do
    subject { described_class.new }
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

    it "each instance has its own connection" do
      configuration1 = described_class.new
      configuration1.connection_opts = {host: host}
      configuration2 = described_class.new
      configuration2.connection_opts = {host: host}

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
    let(:version) { Harmoniser::VERSION }
    subject { described_class.new }

    context "when called with empty opts" do
      it "uses default connection opts defined" do
        subject.connection_opts = {}

        expect(subject.connection_opts).to include({
          connection_name: "harmoniser@#{version}",
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
        subject.connection_opts = {host: "wadus", password: "secret_password"}

        expect(subject.connection_opts).to include({
          connection_name: "harmoniser@#{version}",
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

  describe "#define_topology" do
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

  context "forwardable options" do
    subject { described_class.new }

    describe "#environment" do
      it "returns the environment set" do
        result = subject.environment

        expect(result).to eq("production")
      end

      context "when RAILS_ENV is set" do
        before { ENV["RAILS_ENV"] = "development" }
        after { ENV.delete("RAILS_ENV") }

        it "returns the environment set at RAILS_ENV" do
          result = subject.environment

          expect(result).to eq("development")
        end
      end

      context "when RACK_ENV is set" do
        before { ENV["RACK_ENV"] = "test" }
        after { ENV.delete("RACK_ENV") }

        it "returns the environmet set at RACK_ENV" do
          result = subject.environment

          expect(result).to eq("test")
        end
      end
    end

    describe "#verbose" do
      it "returns whether or not verbose is set" do
        result = subject.verbose

        expect(result).to eq(false)
      end
    end

    describe "require" do
      it "returns the entrypoint file used for boot" do
        result = subject.require

        expect(result).to eq(".")
      end
    end
  end

  describe "#logger" do
    subject { described_class.new }

    it "severity is INFO by default" do
      expect(subject.logger.debug?).to eq(false)
    end

    context "when environment is NOT production" do
      before { ENV["RACK_ENV"] = "test" }
      after { ENV.delete("RACK_ENV") }

      it "severity is DEBUG by default" do
        expect(subject.logger.debug?).to eq(true)
      end
    end
  end

  describe "#options_with" do
    subject { described_class.new }

    it "sets options with options passed" do
      subject.options_with(environment: "development", require: "a_file.rb", verbose: true)

      expect(subject.environment).to eq("development")
      expect(subject.require).to eq("a_file.rb")
      expect(subject.verbose).to eq(true)
    end

    context "when invalid option is passed" do
      it "raises ArgumentError with invalid option" do
        expect do
          subject.options_with(wadus: true)
        end.to raise_error(ArgumentError)
      end
    end

    context "when environment is passed" do
      context "being production" do
        it "logger severity is INFO" do
          subject.options_with(environment: "production")

          expect(subject.logger.debug?).to eq(false)
        end
      end

      context "not being production" do
        it "logger severity is DEBUG" do
          subject.options_with(environment: "wadus")

          expect(subject.logger.debug?).to eq(true)
        end
      end
    end

    context "when verbose is passed" do
      context "being true" do
        it "logger severity is DEBUG" do
          subject.options_with(verbose: true)

          expect(subject.logger.debug?).to eq(true)
        end
      end

      context "not being true" do
        it "logger severity is INFO" do
          subject.options_with(verbose: false)

          expect(subject.logger.debug?).to eq(false)
        end
      end
    end
  end
end
