RSpec.describe Harmoniser do
  it "has a version number" do
    expect(described_class::VERSION).not_to be nil
  end

  describe ".configuration" do
    it "respond_to configuration" do
      expect(described_class).to respond_to(:configuration)
    end
  end

  describe ".configure" do
    it "respond_to configure" do
      expect(described_class).to respond_to(:configure)
    end
  end
end
