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
end
