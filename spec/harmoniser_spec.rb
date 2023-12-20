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

  describe ".default_configuration" do
    it "respond_to default_configuration" do
      expect(described_class).to respond_to(:default_configuration)
    end
  end

  describe ".logger" do
    it "respond_to logger" do
      expect(described_class).to respond_to(:logger)
    end
  end
end
