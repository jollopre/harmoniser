require "harmoniser/options"

RSpec.describe Harmoniser::Options do
  let(:concurrency) { Float::INFINITY }
  let(:environment) { "production" }
  let(:require) { "." }
  let(:timeout) { 25 }
  let(:verbose) { false }

  subject { described_class.new(concurrency:, environment:, require:, timeout:, verbose:) }

  describe "#unbounded_concurrency?" do
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
