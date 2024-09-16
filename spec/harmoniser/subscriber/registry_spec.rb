require "harmoniser/subscriber/registry"

RSpec.describe Harmoniser::Subscriber::Registry do
  describe "#<<" do
    subject { described_class.new }
    let(:a_class) { Class.new {} }

    it "adds a given class to the registry" do
      subject << a_class

      expect(subject.to_a).to eq([a_class])
    end

    it "same class cannot be added again" do
      subject << a_class
      subject << a_class

      expect(subject.to_a).to eq([a_class])
    end

    it "registry cannot be mutated" do
      subject << a_class

      subject.to_a << "wadus"

      expect(subject.to_a).to eq([a_class])
    end
  end
end
