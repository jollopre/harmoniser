require "harmoniser/launcher"

RSpec.describe Harmoniser::Launcher do
  describe "#start" do
    let(:configuration) { Harmoniser::Configuration.new }
    let(:logger) { Logger.new(IO::NULL) }
    subject { described_class.new(configuration: configuration, logger: logger) }

    context "boot_app" do
      context "when require is a directory" do
        before do
          configuration.options_with(require: ".")
        end

        context "and `config/environment` file does not exist" do
          it "warn logs about no subscribers will run" do
            expect(logger).to receive(:warn).with(/Error while requiring file within directory. No subscribers will run for this process:/)

            subject.start
          end
        end
      end

      context "when require is a file" do
        before do
          configuration.options_with(require: "./file_to_require")
        end

        context "and cannot be loaded" do
          it "warn logs about the problem requiring the file" do
            expect(logger).to receive(:warn).with(/Error while requiring file. No subscribers will run for this process: require = /)

            subject.start
          end
        end
      end
    end

    it "start subscribers for the classes that included Harmoniser::Subscriber" do
      expect(logger).to receive(:info).with(/Subscribers registered to consume messages from queues: klasses = `\[\]`/)

      subject.start
    end
  end
end
