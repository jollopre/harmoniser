require "harmoniser/configurable"

RSpec.describe Harmoniser::Configurable do
  subject do
    Class.new do
      extend Harmoniser::Configurable
    end
  end

  describe ".configure" do
    it "yield a configuration object" do
      expect do |b|
        subject.configure(&b)
      end.to yield_with_args(be_an_instance_of(Harmoniser::Configuration))
    end

    it "configuration object is memoized" do
      configuration = nil
      configuration2 = nil

      subject.configure { |config| configuration = config }
      subject.configure { |config| configuration2 = config }

      expect(configuration.object_id).to eq(configuration2.object_id)
    end
  end

  describe ".configuration" do
    it "return configuration object" do
      subject.configure {}

      expect(subject.configuration).to be_an_instance_of(Harmoniser::Configuration)
    end
  end

  

  describe ".connection" do
    it "forward to configuration object" do
      subject.configure { |config| config.connection_opts = { host: "rabbitmq" } }

      expect(subject.connection).to be_an_instance_of(Harmoniser::Connection)
    end

    context "when configuration object is not set" do
      it "raise NoMethodError" do
        expect do
          subject.connection
        end.to raise_error(NoMethodError, /Please, configure first/)
      end
    end
  end

  describe ".default_configuration" do
    it "returns configuration object" do
      result = subject.default_configuration

      expect(result).to be_an_instance_of(Harmoniser::Configuration)
    end

    it "configuration object is memoized" do
      configuration = subject.default_configuration
      configuration2 = subject.default_configuration

      expect(configuration.object_id).to eq(configuration2.object_id)
    end
  end

  describe ".logger" do
    it "forward to configuration object" do
      subject.configure {}

      expect(subject.logger).to be_an_instance_of(Logger)
    end

    context "when configuration object is not set" do
      it "raise NoMethodError" do
        expect do
          subject.logger
        end.to raise_error(NoMethodError, /Please, configure first/)
      end
    end
  end
end
