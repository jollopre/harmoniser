# frozen_string_literal: true

require "harmoniser/channel"
require "shared_context/configurable"

RSpec.describe Harmoniser::Channel do
  include_context "configurable"

  subject { Harmoniser::Subscriber.create_channel }

  describe "#open?" do
    it "returns true on a freshly created channel" do
      expect(subject.open?).to eq(true)
    end

    it "returns false after close" do
      subject.close

      expect(subject.open?).to eq(false)
    end
  end

  describe "#close" do
    it "closes the underlying bunny channel" do
      subject.close

      expect(subject.bunny_channel.open?).to eq(false)
    end

    context "when the channel is already closed" do
      it "returns false and warns about the failure" do
        subject.bunny_channel.close

        expect do
          result = subject.close
          expect(result).to eq(false)
        end.to output(/Failed to close channel: exception = `/).to_stdout_from_any_process
      end
    end

    context "when a custom logger is injected" do
      let(:custom_logger) { Logger.new(IO::NULL) }
      subject(:channel_with_custom_logger) do
        described_class.new(Harmoniser::Subscriber.create_channel.bunny_channel, logger: custom_logger)
      end

      it "uses the injected logger to warn about the failure" do
        channel_with_custom_logger.bunny_channel.close
        expect(custom_logger).to receive(:warn).with(/Failed to close channel: exception = `/)

        channel_with_custom_logger.close
      end
    end
  end

  describe "#synchronize" do
    it "returns the value of the block" do
      expect(subject.synchronize { :result }).to eq(:result)
    end

    it "serialises blocks across threads" do
      locked = Queue.new
      release = Queue.new
      events = Queue.new
      holder = Thread.new do
        subject.synchronize do
          locked << true
          release.pop
          events << :holder_finished
        end
      end
      locked.pop
      waiter = Thread.new { subject.synchronize { events << :waiter_finished } }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      Thread.pass until waiter.status != "run" || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      expect(events.size).to eq(0)

      release << true
      [holder, waiter].each { |thread| thread.join(5) }

      expect(Array.new(events.size) { events.pop }).to eq([:holder_finished, :waiter_finished])
    end
  end

  describe "#synchronize re-entry" do
    it "allows the thread holding the lock to enter it again" do
      expect(subject.synchronize { subject.synchronize { :reentered } }).to eq(:reentered)
    end
  end

  describe "on_error_callback" do
    context "when a custom logger is injected" do
      let(:custom_logger) { Logger.new(IO::NULL) }
      subject(:channel_with_custom_logger) do
        described_class.new(Harmoniser::Subscriber.create_channel.bunny_channel, logger: custom_logger)
      end

      it "uses the injected logger to warn about the channel error" do
        amq_method = AMQ::Protocol::Channel::Close.new(406, "unknown delivery tag", nil, nil)
        on_error = channel_with_custom_logger.bunny_channel.instance_variable_get(:@on_error)
        expect(custom_logger).to receive(:warn).with(/Default on_error handler executed for channel:/)

        on_error.call(channel_with_custom_logger.bunny_channel, amq_method)
      end
    end
  end
end
