require "harmoniser/connectable"
require "shared_context/configurable"

RSpec.describe Harmoniser::Connectable do
  let(:klass) do
    Class.new do
      include Harmoniser::Connectable
    end
  end

  include_context "configurable"

  describe ".connection" do
    it "creates a connection to RabbitMQ using Connection underneath" do
      expect_any_instance_of(Harmoniser::Connection).to receive(:start)

      klass.connection
    end

    it "connection creation is thread-safe" do
      connection_creation = lambda { klass.connection }

      result1 = Thread.new(&connection_creation)
      result2 = Thread.new(&connection_creation)

      expect(result1.value.object_id).to eq(result2.value.object_id)
    end

    it "a closed connection can be re-opened" do
      bunny_instance = klass.connection.instance_variable_get(:@bunny)
      klass.connection.close

      expect(bunny_instance.open?).to eq(false)
      expect(klass.connection.open?).to eq(true)
    end

    it "a closed connection due to a network failure CANNOT be re-opened" do
      bunny_instance = klass.connection.instance_variable_get(:@bunny)
      klass.connection.close
      bunny_instance.instance_variable_set(:@recovering_from_network_failure, true)

      expect(klass.connection.open?).to eq(false)
    end
  end

  describe ".connection?" do
    context "when connection is invoked" do
      it "returns true" do
        klass.connection

        expect(klass.connection?).to eq(true)
      end
    end

    it "returns false" do
      expect(klass.connection?).to eq(false)
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
      subject(:channel) { klass.create_channel }

      it "log with error severity is output" do
        method = AMQ::Protocol::Channel::Close.new(406, "unknown delivery tag", nil, nil)
        on_error = channel.instance_variable_get(:@on_error)

        expect do
          on_error.call(subject, method)
        end.to output(/ERROR -- .*Default on_error handler executed for channel: amq_method = `.*`, exchanges = `\[\]`, queues = `\[\]`, reply_code = `406`, reply_text = `unknown delivery tag`/).to_stdout_from_any_process
      end

      context "for any other amq_method is received" do
        it "log with error severity is output but does not include `reply_code` nor `reply_text`" do
          method = AMQ::Protocol::Channel::CloseOk.new
          on_error = channel.instance_variable_get(:@on_error)

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
          on_error = channel.instance_variable_get(:@on_error)

          on_error.call(subject, method)

          expect(Process).to have_received(:kill).with("USR1", anything)
        end

        context "but harmoniser is NOT the running process" do
          before do
            allow(Harmoniser).to receive(:server?).and_return(false)
          end

          it "does not terminate the process" do
            on_error = channel.instance_variable_get(:@on_error)

            on_error.call(subject, method)

            expect(Process).not_to have_received(:kill).with(anything, anything)
          end
        end
      end
    end

    context "when an error occurs consuming a message" do
      subject(:channel) { klass.create_channel }

      it "log with error severity is output" do
        on_uncaught_exception = channel.instance_variable_get(:@uncaught_exception_handler)
        consumer = Bunny::Consumer.new(channel, "a_queue")

        expect do
          on_uncaught_exception.call(StandardError.new("wadus"), consumer)
        end.to output(/ERROR -- .*Default on_uncaught_exception handler executed for channel/).to_stdout_from_any_process
      end
    end
  end
end
