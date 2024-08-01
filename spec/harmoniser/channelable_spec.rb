require "harmoniser/channelable"
require "shared_context/configurable"

RSpec.describe Harmoniser::Channelable do
  include_context "configurable"

  let(:klass) do
    Class.new do
      include Harmoniser::Channelable
    end
  end

  it "MUTEX constant is private" do
    expect do
      klass::MUTEX
    end.to raise_error(NameError, /private constant/)
  end

  describe ".harmoniser_channel" do
    it "return a Bunny::Channel" do
      result = klass.harmoniser_channel

      expect(result).to be_an_instance_of(Bunny::Channel)
    end

    it "channel creation is thread-safe" do
      channel_creation = lambda { klass.harmoniser_channel }

      result1 = Thread.new(&channel_creation)
      result2 = Thread.new(&channel_creation)

      expect(result1.value.object_id).to eq(result2.value.object_id)
    end
  end

  describe ".create_channel" do
    it "creates a Bunny::Channel with the consumer_pool_size specified" do
      result = klass.create_channel(consumer_pool_size: 10)

      expect(result.work_pool.size).to eq(10)
    end

    context "when no consumer_pool_size is passed" do
      it "creates a Bunny::Channel with consumer_pool_size to 1" do
        result = klass.create_channel

        expect(result.work_pool.size).to eq(1)
      end
    end

    context "when an error occurs at channel level" do
      subject { klass.harmoniser_channel }

      it "log with error severity is output" do
        method = AMQ::Protocol::Channel::Close.new(406, "unknown delivery tag", nil, nil)
        on_error = subject.instance_variable_get(:@on_error)

        expect do
          on_error.call(subject, method)
        end.to output(/ERROR -- .*Default on_error handler executed for channel: amq_method = `.*`, exchanges = `\[\]`, queues = `\[\]`, reply_code = `406`, reply_text = `unknown delivery tag`/).to_stdout_from_any_process
      end

      context "for any other amq_method is received" do
        it "log with error severity is output but does not include `reply_code` nor `reply_text`" do
          method = AMQ::Protocol::Channel::CloseOk.new
          on_error = subject.instance_variable_get(:@on_error)

          expect do
            on_error.call(subject, method)
          end.to output(/ERROR -- .*Default on_error handler executed for channel: amq_method = `.*`, exchanges = `\[\]`, queues = `\[\]`/).to_stdout_from_any_process
        end
      end

      context "when ack timeout is received" do
        let(:method) do
          AMQ::Protocol::Channel::Close.new(406, "delivery acknowledgement on channel 1 timed out", nil, nil)
        end

        before do
          allow(Harmoniser).to receive(:server?).and_return(true)
          allow(Process).to receive(:kill).with("USR1", anything)
        end

        it "terminates the process with USR1 signal" do
          on_error = subject.instance_variable_get(:@on_error)

          on_error.call(subject, method)

          expect(Process).to have_received(:kill).with("USR1", anything)
        end

        context "but harmoniser is NOT the running process" do
          before do
            allow(Harmoniser).to receive(:server?).and_return(false)
          end

          it "does not terminate the process" do
            on_error = subject.instance_variable_get(:@on_error)

            on_error.call(subject, method)

            expect(Process).not_to have_received(:kill).with(anything, anything)
          end
        end
      end
    end

    context "when an error occurs consuming a message" do
      it "log with error severity is output" do
        channel = klass.harmoniser_channel
        on_uncaught_exception = channel.instance_variable_get(:@uncaught_exception_handler)
        consumer = Bunny::Consumer.new(channel, "a_queue")

        expect do
          on_uncaught_exception.call(StandardError.new("wadus"), consumer)
        end.to output(/ERROR -- .*Default on_uncaught_exception handler executed for channel/).to_stdout_from_any_process
      end
    end
  end
end
