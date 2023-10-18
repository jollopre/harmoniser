require "harmoniser/connection"
require "shared_context/configurable"

RSpec.describe Harmoniser::Connection do
  subject { described_class.new({}) }

  it "responds to close" do
    expect(subject).to respond_to(:close)
  end

  it "responds to create_channel" do
    expect(subject).to respond_to(:create_channel)
  end

  it "responds to open?" do
    expect(subject).to respond_to(:open?)
  end

  it "responds to start" do
    expect(subject).to respond_to(:start)
  end
end
