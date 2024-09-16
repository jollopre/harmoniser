require "harmoniser/launcher"
require "shared_context/configurable"

RSpec.describe Harmoniser::Launcher do
  include_context "configurable"

  let(:configuration) do
    Harmoniser.configuration
  end
  let(:logger) { Logger.new(IO::NULL) }
  subject do
    described_class.call(configuration: configuration, logger: logger)
  end
  let(:content) do
    <<~RUBY
      Harmoniser.configure do |config|
        config.define_topology do |topology|
          topology.add_queue("my_first_queue_for_launcher")
          topology.add_queue("my_second_queue_for_launcher")
          topology.declare
        end
      end

      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber queue_name: "my_first_queue_for_launcher", no_ack: true
      end

      Class.new do
        include Harmoniser::Subscriber
        harmoniser_subscriber queue_name: "my_second_queue_for_launcher", no_ack: false
      end
    RUBY
  end
  let(:filepath) do
    require "securerandom"
    "/tmp/#{SecureRandom.uuid}.rb".tap do |filepath|
      File.write(filepath, content)
    end
  end
  before(:each) do
    Harmoniser::Subscriber.instance_variable_set(:@registry, nil)
  end
  after(:each) do
    File.delete(filepath) if File.exist?(filepath)
  end

  shared_examples "bootable issues" do |require_file|
    context "when require is a directory" do
      context "and `config/environment` file does not exist" do
        before do
          configuration.options_with(require: ".")
        end

        it "warn logs about no subscribers will run" do
          expect(logger).to receive(:warn).with(/Error while requiring file within directory. No subscribers will run for this process: require = `.*`, filepath = `.*`, error_class = `.*`, error_message = `.*`, error_backtrace = `.*`/)

          subject.start
        end

        it "logs no klasses registered" do
          expect(logger).to receive(:info).with(/Subscribers registered to consume messages from queues: klasses = `\[\]`/)

          subject.start
        end
      end
    end

    context "when require is a file" do
      context "and cannot be loaded" do
        before do
          configuration.options_with(require: "./file_to_require")
        end

        it "warn logs about the problem requiring the file" do
          expect(logger).to receive(:warn).with(/Error while requiring file. No subscribers will run for this process: require = `.*`, error_class = `LoadError`, error_message = `.*`, error_backtrace = `.*`/)

          subject.start
        end

        it "logs no klasses registered" do
          expect(logger).to receive(:info).with(/Subscribers registered to consume messages from queues: klasses = `\[\]`/)

          subject.start
        end
      end
    end
  end

  describe "unbounded concurrency launcher" do
    describe "#start" do
      it_behaves_like "bootable issues"

      it "each subscriber has its own channel with work pool to 1" do
        configuration.options_with(require: filepath, concurrency: Float::INFINITY)

        subject.start

        consumers = subject.subscribers.map { |subscriber| subscriber.instance_variable_get(:@harmoniser_consumer) }
        first_consumer = consumers.first
        second_consumer = consumers.last
        expect(first_consumer.channel).not_to eq(second_consumer.channel)
        expect(first_consumer.channel.work_pool.size).to eq(1)
        expect(second_consumer.channel.work_pool.size).to eq(1)
      end

      it "each subscriber has its own channel with work pool shutdown timeout to 60 seconds" do
        configuration.options_with(require: filepath, concurrency: Float::INFINITY)
        allow_any_instance_of(Bunny::Session).to receive(:create_channel).with(nil, 1, false, 60).and_call_original

        subject.start
      end
    end

    describe "#stop" do
      it "cancels subscribers, informs about work pool and closes connection" do
        configuration.options_with(require: filepath, concurrency: Float::INFINITY)
        subject.start

        expect(logger).to receive(:info).with("Shutting down!")
        expect(logger).to receive(:info).with(/Subscribers will be cancelled from queues: klasses = /)
        expect(logger).to receive(:info).with(/Subscribers cancelled: klasses = /)
        expect(logger).to receive(:info).with(/Stats about the work pool: work_pool_reporter = .*\. Note: A backlog greater than zero means messages could be lost for subscribers configured with no_ack, i.e. automatic ack/)
        expect(logger).to receive(:info).with(/Connection will be closed: connection =/)
        expect(logger).to receive(:info).with(/Connection closed: connection =/)
        expect(logger).to receive(:info).with("Bye!")

        subject.stop
      end
    end
  end

  describe "bounded concurrency launcher" do
    let(:concurrency) { 5 }

    describe "#start" do
      it_behaves_like "bootable issues"

      it "every subscriber share the channel with work pool to concurrency passed" do
        configuration.options_with(require: filepath, concurrency: concurrency)

        subject.start

        consumers = subject.subscribers.map { |subscriber| subscriber.instance_variable_get(:@harmoniser_consumer) }
        first_consumer = consumers.first
        second_consumer = consumers.last
        expect(first_consumer.channel).to eq(second_consumer.channel)
        expect(first_consumer.channel.work_pool.size).to eq(concurrency)
        expect(second_consumer.channel.work_pool.size).to eq(concurrency)
      end

      it "the shared channel has work pool shutdown timeout to 25 seconds" do
        configuration.options_with(require: filepath, concurrency: concurrency)
        allow(Harmoniser::Launcher::Bounded).to receive(:create_channel).and_call_original

        subject.start

        expect(Harmoniser::Launcher::Bounded).to have_received(:create_channel).with(consumer_pool_size: concurrency, consumer_pool_shutdown_timeout: 25)
      end
    end

    describe "#stop" do
      it "cancels subscribers, informs about work pool and closes connection" do
        configuration.options_with(require: filepath, concurrency: concurrency)
        subject.start

        expect(logger).to receive(:info).with("Shutting down!")
        expect(logger).to receive(:info).with(/Subscribers will be cancelled from queues: klasses = /)
        expect(logger).to receive(:info).with(/Subscribers cancelled: klasses = /)
        expect(logger).to receive(:info).with(/Stats about the work pool: work_pool_reporter = .*\. Note: A backlog greater than zero means messages could be lost for subscribers configured with no_ack, i.e. automatic ack/)
        expect(logger).to receive(:info).with(/Connection will be closed: connection =/)
        expect(logger).to receive(:info).with(/Connection closed: connection =/)
        expect(logger).to receive(:info).with("Bye!")

        subject.stop
      end
    end
  end
end
