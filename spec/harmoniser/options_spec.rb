require "harmoniser/options"

RSpec.describe Harmoniser::Options do
  describe ".new" do
    it "initializes with default values" do
      result = described_class.new

      expect(result.concurrency).to eq(Float::INFINITY)
      expect(result.environment).to eq("production")
      expect(result.require).to eq(".")
      expect(result.timeout).to eq(25)
      expect(result.verbose).to eq(false)
    end
  end

  describe "#unbounded_concurrency?" do
    let(:concurrency) { Float::INFINITY }
    subject { described_class.new(concurrency:) }

    it "returns true" do
      expect(subject.unbounded_concurrency?).to eq(true)
    end

    context "when concurreny is other than infinity" do
      let(:concurrency) { 5 }

      it "returns false" do
        expect(subject.unbounded_concurrency?).to eq(false)
      end
    end
  end
end
