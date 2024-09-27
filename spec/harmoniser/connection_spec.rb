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
      it "does not override them" do
        allow(Bunny).to receive(:new).and_call_original

        described_class.new({
          logger: "foo",
          recovery_attempt_started: "bar",
          recovery_completed: "baz"
        })

        expect(Bunny).to have_received(:new).with(include(
          logger: "foo",
          recovery_attempt_started: "bar",
          recovery_completed: "baz"
        ))
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

    context "when closing connection fails" do
      it "returns false" do
        allow(bunny).to receive(:close).and_raise("Error")

        result = subject.close

        expect(result).to eq(false)
      end

      it "log with error severity is output" do
        allow(bunny).to receive(:close).and_raise("Error")
        allow(logger).to receive(:error)

        subject.close

        expect(logger).to have_received(:error).with(/Connection#close failed: error_class = `RuntimeError`, error_message = `Error`/)
      end
    end
  end

  describe "#start" do
    before do
      allow(subject).to receive(:exit)
    end

    let(:bunny) { subject.instance_variable_get(:@bunny) }

    it "retries establishing connection until succeeding" do
      allow(logger).to receive(:error)
      allow(subject).to receive(:sleep)
      allow(bunny).to receive(:start) do
        @retries ||= 0
        if @retries < 2
          @retries += 1
          raise "Error"
        end
      end

      subject.start

      expect(logger).to have_received(:error).with(/Connection attempt failed: retries = `.*`, error_class = `RuntimeError`, error_message = `Error`/).twice
    end

    context "when a OS signal is received while connecting" do
      before do
        allow(bunny).to receive(:start).and_raise(SignalException.new("SIGINT"))
      end

      context "and harmoniser is the main process" do
        before { allow(Harmoniser).to receive(:server?).and_return(true) }

        it "invokes exit with zero" do
          subject.start

          expect(subject).to have_received(:exit).with(0)
        end
      end

      it "re-raises the exception" do
        expect do
          subject.start
        end.to raise_error(SignalException)
      end
    end
  end

  describe "#to_s" do
    it "returns a string representation of the connection" do
      expect(subject.to_s).to match(/<Harmoniser::Connection>:[0-9]+ guest@127.0.0.1:5672, connection_name = `wadus`, vhost = `\/`/)
    end
  end
end
