require "harmoniser/configuration"

RSpec.describe Harmoniser::Configuration do
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

    context "connectable" do
      subject { described_class.new }

      it "responds to connection_opts" do
        expect(subject).to respond_to(:connection_opts)
      end

      it "responds to connection_opts=" do
        expect(subject).to respond_to(:connection_opts=)
      end

      it "responds to connection" do
        expect(subject).to respond_to(:connection)
      end

      it "responds to connection?" do
        expect(subject).to respond_to(:connection?)
      end
    end
  end

  describe "#logger" do
    subject { described_class.new }

    it "severity is INFO by default" do
      expect(subject.logger.debug?).to eq(false)
    end

    context "when is verbose mode" do
      it "severity is DEBUG" do
        subject.options_with(verbose: true)

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
