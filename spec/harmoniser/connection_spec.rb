require "harmoniser/connection"
require "shared_context/configurable"

RSpec.describe Harmoniser::Connection do
  let(:logger) { Harmoniser.logger }
  subject { described_class.new({connection_name: "wadus"}, logger: logger) }

  it "responds to close" do
    expect(subject).to respond_to(:close)
  end

  it "responds to create_channel" do
    expect(subject).to respond_to(:create_channel)
  end

  it "responds to open?" do
    expect(subject).to respond_to(:open?)
  end

  it "respond to recovering_from_network_failure?" do
    expect(subject).to respond_to(:recovering_from_network_failure?)
  end

  describe ".initialize" do
    it "forwards dynamic opts to Bunny" do
      allow(Bunny).to receive(:new).and_call_original

      described_class.new({})

      expect(Bunny).to have_received(:new).with(include(
        logger: logger,
        recovery_attempt_started: be_a(Proc),
        recovery_completed: be_a(Proc)
      ))
    end

    context "when dynamic opts are already present" do
      let(:calls) { [] }
      let(:app_recovery_attempt_started) { proc { calls << [:app_started, connection.instance_variable_get(:@ready)] } }
      let(:app_recovery_completed) { proc { calls << [:app_completed, connection.instance_variable_get(:@ready)] } }
      let(:connection) do
        described_class.new({
          logger: "foo",
          recovery_attempt_started: app_recovery_attempt_started,
          recovery_completed: app_recovery_completed
        }, logger: Logger.new(IO::NULL))
      end
      let(:bunny) { connection.instance_variable_get(:@bunny) }

      it "forwards the logger as is" do
        allow(Bunny).to receive(:new).and_call_original

        connection

        expect(Bunny).to have_received(:new).with(include(logger: "foo"))
      end

      it "forwards Harmoniser's recovery callbacks instead of the app's ones" do
        allow(Bunny).to receive(:new).and_call_original

        connection

        expect(Bunny).to have_received(:new).with(include(
          recovery_attempt_started: be_a(Proc).and(satisfy { |callback| !callback.equal?(app_recovery_attempt_started) }),
          recovery_completed: be_a(Proc).and(satisfy { |callback| !callback.equal?(app_recovery_completed) })
        ))
      end

      it "calls the app's recovery callbacks after Harmoniser's ones" do
        bunny.instance_variable_get(:@recovery_attempt_started).call
        bunny.instance_variable_get(:@recovery_completed).call

        expect(calls).to eq([[:app_started, false], [:app_completed, true]])
      end
    end
  end

  describe "#ready?" do
    let(:bunny) { subject.instance_variable_get(:@bunny) }

    it "returns false when the connection is not open" do
      allow(bunny).to receive(:open?).and_return(false)

      expect(subject.ready?).to eq(false)
    end

    it "returns true when the connection is open and no recovery is in progress" do
      allow(bunny).to receive(:open?).and_return(true)

      expect(subject.ready?).to eq(true)
    end
  end

  describe "recovery callbacks" do
    let(:logger) { Logger.new(IO::NULL) }
    let(:bunny) { subject.instance_variable_get(:@bunny) }
    let(:recovery_attempt_started) { bunny.instance_variable_get(:@recovery_attempt_started) }
    let(:recovery_completed) { bunny.instance_variable_get(:@recovery_completed) }
    let(:bunny_channel) { double("Bunny::Channel", cancel_consumers_before_closing!: nil, on_error: nil, on_uncaught_exception: nil) }
    let(:channel) { Harmoniser::Channel.new(bunny_channel, logger: logger).tap { |ch| subject.register_channel(ch) } }

    before { allow(bunny).to receive(:open?).and_return(true) }

    it "flips ready? to false when a recovery attempt starts" do
      expect { recovery_attempt_started.call }.to change { subject.ready? }.from(true).to(false)
    end

    it "flips ready? to true when the recovery is completed" do
      recovery_attempt_started.call

      expect { recovery_completed.call }.to change { subject.ready? }.from(false).to(true)
    end

    it "logs the recovery attempt and its completion" do
      expect(logger).to receive(:info).with(/Recovery attempt started: connection = `.*`/)
      expect(logger).to receive(:info).with(/Recovery completed: connection = `.*`/)

      recovery_attempt_started.call
      recovery_completed.call
    end

    context "when another thread holds a channel lock" do
      it "waits until the lock is released before returning" do
        events = Queue.new
        locked = Queue.new
        release = Queue.new
        holder = Thread.new do
          channel.synchronize do
            locked << true
            release.pop
            events << :publish_finished
          end
        end
        locked.pop

        recovery = Thread.new do
          recovery_attempt_started.call
          events << :barrier_returned
        end
        wait_until_blocked(recovery)

        expect(events.size).to eq(0)
        expect(subject.ready?).to eq(false)

        release << true
        [holder, recovery].each { |thread| thread.join(5) }

        expect(Array.new(events.size) { events.pop }).to eq([:publish_finished, :barrier_returned])
      end
    end

    context "when the recovery runs on the thread that holds a channel lock" do
      it "re-enters that lock without raising ThreadError" do
        channel.synchronize do
          expect { recovery_attempt_started.call }.not_to raise_error
        end

        expect(subject.ready?).to eq(false)
      end
    end

    def wait_until_blocked(thread)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until thread.status != "run"
        raise "thread did not block in time" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Thread.pass
      end
    end
  end

  context "callbacks" do
    let(:bunny) { subject.instance_variable_get(:@bunny) }
    let(:blocked) { AMQ::Protocol::Connection::Blocked.new("a reason") }
    let(:unblocked) { AMQ::Protocol::Connection::Unblocked.new }

    context "when the connection is blocked" do
      it "warns about its reason" do
        expect(logger).to receive(:warn).with(/Connection blocked: connection = `.*`, reason = `a reason`/)

        bunny.instance_variable_get(:@block_callback).call(blocked)
      end
    end

    context "when the connection is unblocked" do
      it "informs about it" do
        expect(logger).to receive(:info).with(/Connection unblocked: connection = `.*`/)

        bunny.instance_variable_get(:@unblock_callback).call(unblocked)
      end
    end
  end

  describe "#register_channel" do
    include_context "configurable"

    subject { described_class.new({connection_name: "wadus", host: host}, logger: logger).tap(&:start) }

    after { subject.close }

    it "registers the channel so it is tracked by the connection" do
      channel = Harmoniser::Channel.new(subject.create_channel)

      subject.register_channel(channel)

      expect(subject.instance_variable_get(:@channels)).to include(channel)
    end
  end

  describe "#close" do
    let(:bunny) { subject.instance_variable_get(:@bunny) }

    it "returns true" do
      expect(bunny).to receive(:close).and_call_original

      result = subject.close

      expect(result).to eq(true)
    end

    it "informs about closing" do
      expect(logger).to receive(:info).with(/Connection will be closed: connection =/)
      expect(logger).to receive(:info).with(/Connection closed: connection =/)

      subject.close
    end

    context "when a channel is registered" do
      include_context "configurable"

      subject { described_class.new({connection_name: "wadus", host: host}, logger: logger).tap(&:start) }

      let(:channel) do
        Harmoniser::Channel.new(subject.create_channel).tap do |ch|
          subject.register_channel(ch)
        end
      end

      it "closes the channel before closing the connection" do
        channel

        subject.close

        expect(channel.open?).to eq(false)
      end

      context "when the channel is already closed" do
        it "does not raise" do
          channel.bunny_channel.close

          expect { subject.close }.not_to raise_error
        end
      end
    end

    context "when closing connection fails" do
      it "returns false" do
        allow(bunny).to receive(:close).and_raise("Error")

        result = subject.close

        expect(result).to eq(false)
      end

      it "log with error severity is output" do
        allow(bunny).to receive(:close).and_raise("Error")

        expect do
          subject.close
        end.to output(/.*ERROR -- .*Connection close failed"/).to_stdout_from_any_process
      end
    end
  end

  describe "#start" do
    let(:bunny) { subject.instance_variable_get(:@bunny) }

    context "when `server?`" do
      before do
        allow(Harmoniser).to receive(:server?).and_return(true)
        allow(subject).to receive(:sleep)
        allow(bunny).to receive(:start) do
          @retries ||= 0
          if @retries < 2
            @retries += 1
            raise "Error"
          end
        end
      end

      it "retries establishing connection until succeeding" do
        expect do
          subject.start
        end.to output(/.*ERROR -- .*"Connection attempt failed".*ERROR -- .*"Connection attempt failed"/m).to_stdout_from_any_process
      end
    end

    it "does not perform retries and propagates the error" do
      allow(bunny).to receive(:start).and_raise("Error")
      expect do
        subject.start
      end.to raise_error("Error")
    end
  end

  describe "#to_s" do
    it "returns a string representation of the connection" do
      expect(subject.to_s).to match(/<Harmoniser::Connection>:[0-9]+ guest@127.0.0.1:5672, connection_name = `wadus`, vhost = `\/`/)
    end
  end
end
