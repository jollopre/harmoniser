require "harmoniser/work_pool_reporter"
require "shared_context/configurable"

RSpec.describe Harmoniser::WorkPoolReporter do
  include_context "configurable"

  describe "to_s" do
    let(:exchange_name) { "harmoniser_publisher_exchange" }
    let(:queue_name) { "queue_harmoniser_publisher_exchange" }
    let(:subscribers) do
      [
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber queue_name: "queue_harmoniser_publisher_exchange"
        end,
        Class.new do
          include Harmoniser::Subscriber
          harmoniser_subscriber queue_name: "queue_harmoniser_publisher_exchange"
        end
      ]
    end
    let(:consumers) { subscribers.map(&:harmoniser_subscriber_start) }
    before(:each) do
      declare_exchange(exchange_name)
      declare_queue(queue_name, exchange_name)
    end
    subject { described_class.new(consumers: consumers) }

    it "outputs stats about the work pool for each consumer" do
      result = subject.to_s
      expect(result).to eq("<Harmoniser::WorkPoolReporter>: [\"<#{consumers.first.channel.id}>: backlog = `0`, running? = `true`, queues = `[\\\"queue_harmoniser_publisher_exchange\\\"]`\", \"<#{consumers.last.channel.id}>: backlog = `0`, running? = `true`, queues = `[\\\"queue_harmoniser_publisher_exchange\\\"]`\"]")
    end

    context "when channel is re-used across subscribers" do
      let(:channel) { bunny.create_channel }
      subject { described_class.new(consumers: subscribers.map { |s| s.harmoniser_subscriber_start(channel: channel) }) }
      it "outputs stats about the work pool for each consumer" do
        result = subject.to_s
        expect(result).to eq("<Harmoniser::WorkPoolReporter>: [\"<#{channel.id}>: backlog = `0`, running? = `true`, queues = `[\\\"queue_harmoniser_publisher_exchange\\\"]`\"]")
      end
    end
  end
end
