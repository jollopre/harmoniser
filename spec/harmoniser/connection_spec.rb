require "harmoniser/connection"
require "shared_context/configurable"

RSpec.describe Harmoniser::Connection do
  subject { described_class.new({connection_name: "wadus"}) }

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

  it "responds to start" do
    expect(subject).to respond_to(:start)
  end

  describe "#to_s" do
    it "returns a string representation of the connection" do
      expect(subject.to_s).to eq("<Harmoniser::Connection>: guest@127.0.0.1:5672, connection_name = `wadus`, vhost = `/`")
    end
  end
end
