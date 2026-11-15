require "harmoniser/publisher"
require "shared_context/configurable"
require "erb"
require "json"
require "net/http"
require "securerandom"
require "stringio"

RSpec.describe Harmoniser::Publisher do
  include_context "configurable"

  let(:klass) do
    Class.new do
      include Harmoniser::Publisher
    end
  end
  let(:exchange_name) { "harmoniser_publisher_exchange" }

  describe ".harmoniser_publisher" do
    it "return a Definition::Exchange" do
      result = klass.harmoniser_publisher(exchange_name: exchange_name)

      exchange_definition = Harmoniser::Definition::Exchange.new(name: exchange_name, type: nil, opts: {passive: true})
      expect(result).to eq(exchange_definition)
    end
  end

  describe ".publish" do
    before do
      declare_exchange(exchange_name)
      declare_queue("", exchange_name).subscribe do |_, _, _|
        @consumed = true
      end
      klass.harmoniser_publisher(exchange_name: exchange_name)
    end

    it "publish a message" do
      klass.publish("foo")

      expect do
        require "timeout"
        Timeout.timeout(2) do
          until @consumed; end
        end
      end.not_to raise_error
    end

    it "channel is shared across publisher publications" do
      result1 = klass.publish("foo").channel
      result2 = klass.publish("bar").channel

      expect(result1.object_id).to eq(result2.object_id)
    end

    it "channel is dedicated to each publisher" do
      another_klass = Class.new { include Harmoniser::Publisher }
      another_klass.harmoniser_publisher(exchange_name: exchange_name)
      exchange = klass.publish("foo")
      another_exchange = another_klass.publish("foo")

      expect(exchange.channel).not_to eq(another_exchange.channel)
    end

    context "when verbose mode is set" do
      before do
        Harmoniser.configure { |config| config.options_with(verbose: true) }
      end
      after do
        Harmoniser.configure { |config| config.options_with(verbose: false) }
      end

      it "logs the message published" do
        expect do
          klass.publish("foo")
        end.to output(/DEBUG -- .*Message published/).to_stdout_from_any_process
      end
    end

    context "when exchange does not exist" do
      it "raises Bunny::NotFound" do
        klass.harmoniser_publisher(exchange_name: "wtf")

        expect do
          klass.publish("foo")
        end.to raise_error(Bunny::NotFound)
      end
    end

    context "when Exchange definition is not provided" do
      before { klass.instance_variable_set(:@harmoniser_exchange_definition, nil) }

      it "raises MissingExchangeDefinition" do
        expect do
          klass.publish("foo")
        end.to raise_error(Harmoniser::Publisher::MissingExchangeDefinition, /Please call the harmoniser_publisher class method at/)
      end
    end

    context "when a mandatory message cannot be routed" do
      let(:klass) do
        Class.new do
          include Harmoniser::Publisher
        end
      end

      before do
        declare_exchange("exchange_without_queues")
        klass.harmoniser_publisher(exchange_name: "exchange_without_queues")
      end

      it "log with warn severity is output" do
        expect do
          klass.publish("foo", mandatory: true)
          # TODO find a better way to test this since AMQ::Protocol::Basic::Return comes async after the publication is completed
          sleep 0.2
        end.to output(/WARN -- .*Default on_return handler executed for exchange/).to_stdout_from_any_process
      end
    end
  end

  describe ".publish when the connection is not ready" do
    let(:connection) { described_class.connection }
    let(:bunny) { connection.instance_variable_get(:@bunny) }
    let(:recovery_attempt_started) { bunny.instance_variable_get(:@recovery_attempt_started) }
    let(:recovery_completed) { bunny.instance_variable_get(:@recovery_completed) }

    before do
      declare_exchange(exchange_name)
      klass.harmoniser_publisher(exchange_name: exchange_name)
    end

    it "raises ConnectionNotReady naming the exchange but not the payload" do
      allow(connection).to receive(:ready?).and_return(false)

      expect do
        klass.publish("secret payload")
      end.to raise_error(Harmoniser::Publisher::ConnectionNotReady, /exchange `#{exchange_name}`/) { |error|
        expect(error.message).not_to include("secret payload")
      }
    end

    it "raises ConnectionNotReady while Bunny waits to retry (not open, ready flag still set)" do
      allow(bunny).to receive(:open?).and_return(false)
      allow(bunny).to receive(:recovering_from_network_failure?).and_return(true)

      expect(connection.instance_variable_get(:@ready)).to eq(true)
      expect { klass.publish("foo") }.to raise_error(Harmoniser::Publisher::ConnectionNotReady)
    end

    it "does not call Bunny publish while a recovery is in progress" do
      exchange = klass.publish("foo")
      expect(exchange).not_to receive(:publish)
      recovery_attempt_started.call

      expect { klass.publish("bar") }.to raise_error(Harmoniser::Publisher::ConnectionNotReady)
    ensure
      recovery_completed.call
    end

    it "does not create a channel nor an exchange when the first publish happens during recovery" do
      expect(described_class).not_to receive(:create_channel)
      recovery_attempt_started.call

      expect { klass.publish("foo") }.to raise_error(Harmoniser::Publisher::ConnectionNotReady)
      expect(klass.instance_variable_get(:@harmoniser_channel)).to be_nil
      expect(klass.instance_variable_get(:@harmoniser_exchange)).to be_nil
    ensure
      recovery_completed.call
    end

    it "checks readiness again under the channel lock before publishing" do
      allow(connection).to receive(:ready?).and_return(true, false)

      expect { klass.publish("foo") }.to raise_error(Harmoniser::Publisher::ConnectionNotReady)

      exchange = klass.instance_variable_get(:@harmoniser_exchange)
      expect(exchange).not_to be_nil
      allow(connection).to receive(:ready?).and_return(true)
      expect(exchange).to receive(:publish).once.and_call_original
      klass.publish("bar")
    end

    it "does not reach Publisher.connection once the channel and exchange are created" do
      klass.publish("foo")
      expect(described_class).not_to receive(:connection)

      klass.publish("bar")
    end

    it "publishes again once the recovery is completed" do
      recovery_attempt_started.call
      expect { klass.publish("foo") }.to raise_error(Harmoniser::Publisher::ConnectionNotReady)

      recovery_completed.call

      expect { klass.publish("foo") }.not_to raise_error
    end

    it "lets an in-flight publish finish before the recovery barrier returns" do
      exchange = klass.publish("warm up")
      events = Queue.new
      in_publish = Queue.new
      release = Queue.new
      allow(exchange).to receive(:publish) do
        in_publish << true
        release.pop
        events << :publish_finished
      end

      publisher = Thread.new { klass.publish("foo") }
      in_publish.pop
      recovery = Thread.new do
        recovery_attempt_started.call
        events << :barrier_returned
      end
      wait_until_blocked(recovery)

      expect(events.size).to eq(0)

      release << true
      [publisher, recovery].each { |thread| thread.join(5) }

      expect(Array.new(events.size) { events.pop }).to eq([:publish_finished, :barrier_returned])
    ensure
      recovery_completed.call
    end

    it "does not block publishers of other classes while one is publishing" do
      another_klass = Class.new { include Harmoniser::Publisher }
      another_klass.harmoniser_publisher(exchange_name: exchange_name)
      exchange = klass.publish("warm up")
      in_publish = Queue.new
      release = Queue.new
      allow(exchange).to receive(:publish) do
        in_publish << true
        release.pop
      end

      publisher = Thread.new { klass.publish("foo") }
      in_publish.pop

      another_publisher = Thread.new { another_klass.publish("bar") }
      expect(another_publisher.join(5)).to eq(another_publisher)
      expect(publisher.alive?).to eq(true)
    ensure
      release << true
      publisher&.join(5)
    end

    def wait_until_blocked(thread)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until thread.status != "run"
        raise "thread did not block in time" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Thread.pass
      end
    end
  end

  describe ".publish when the broker force-closes the connection" do
    let(:log) { StringIO.new }
    let(:connection_name) { "harmoniser-recovery-spec-#{SecureRandom.hex(4)}" }
    let(:connection) do
      Harmoniser::Connection.new(
        {host: host, connection_name: connection_name, network_recovery_interval: 1},
        logger: Logger.new(log)
      )
    end

    before do
      @previous_connection = described_class.instance_variable_get(:@connection) if described_class.connection?
      described_class.instance_variable_set(:@connection, connection.tap(&:start))
      declare_exchange(exchange_name)
      @consumed = Queue.new
      declare_queue("", exchange_name).subscribe { |_, _, payload| @consumed << payload }
      klass.harmoniser_publisher(exchange_name: exchange_name)
    end

    after do
      @stop = true
      @publisher&.join(5)
      connection.close
      if @previous_connection
        described_class.instance_variable_set(:@connection, @previous_connection)
      else
        described_class.remove_instance_variable(:@connection)
      end
    end

    it "recovers once, without CHANNEL_ERROR, and publishing resumes" do
      published = Queue.new
      @publisher = Thread.new do
        until @stop
          begin
            klass.publish("message")
            published << :ok
          rescue Harmoniser::Publisher::ConnectionNotReady, Bunny::ConnectionClosedError
            published << :not_ready
          end
          sleep(0.01)
        end
      end
      wait_for(10) { published.size.positive? }

      force_close_connection(connection_name)
      wait_for(30) { log.string.include?("Recovery completed") }
      results = []
      wait_for(10) do
        results << published.pop until published.empty?
        results.last(10) == Array.new(10, :ok)
      end
      @consumed.clear
      wait_for(10) { @consumed.size.positive? }
      sleep(2) # observation window, longer than network_recovery_interval, to detect a second recovery loop
      @stop = true
      @publisher.join(5)

      expect(log.string.scan("Recovery completed").size).to eq(1)
      expect(log.string).not_to include("CHANNEL_ERROR")
      expect(log.string).not_to include("closed stream")
    end

    def wait_for(seconds)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      until yield
        raise "condition not met within #{seconds}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep(0.05)
      end
    end

    def management_request(request)
      uri = request.uri
      request.basic_auth("guest", "guest")
      Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    end

    def force_close_connection(name)
      broker_name = nil
      wait_for(20) do
        response = management_request(Net::HTTP::Get.new(URI("http://#{host}:15672/api/connections")))
        broker_name = JSON.parse(response.body)
          .find { |conn| conn.dig("client_properties", "connection_name") == name }
          &.fetch("name")
      end
      response = management_request(Net::HTTP::Delete.new(URI("http://#{host}:15672/api/connections/#{ERB::Util.url_encode(broker_name)}")))
      raise "failed to close connection: #{response.code}" unless response.code.start_with?("2")
    end
  end

  context "connectable" do
    it "responds to .connection" do
      expect(described_class).to respond_to(:connection)
    end

    it "responds to .connection" do
      expect(described_class).to respond_to(:connection?)
    end

    it "responds to .connection" do
      expect(described_class).to respond_to(:create_channel)
    end
  end
end
