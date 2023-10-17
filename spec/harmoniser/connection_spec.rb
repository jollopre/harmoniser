require "harmoniser/connection"
require "shared_context/configurable"

RSpec.describe Harmoniser::Connection do
  subject { described_class.new({}) }

  it "responds to create_channel" do
    expect(subject).to respond_to(:create_channel)
  end

  it "responds to start" do
    expect(subject).to respond_to(:start)
  end
end
