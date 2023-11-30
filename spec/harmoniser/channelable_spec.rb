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

  context "when an error occurs at channel level" do
    it "log with error severity is output" do
      channel = klass.harmoniser_channel
      method = AMQ::Protocol::Channel::Close.new(406, "unknown delivery tag", nil, nil)
      on_error = channel.instance_variable_get(:@on_error)

      expect do
        on_error.call(channel, method)
      end.to output(/ERROR -- .*Default on_error handler executed for channel:/).to_stdout_from_any_process
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
