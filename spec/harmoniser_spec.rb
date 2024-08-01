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

  describe ".connection" do
    it "responds_to connection" do
      expect(described_class).to respond_to(:connection)
    end
  end

  describe ".connection?" do
    it "responds_to connection?" do
      expect(described_class).to respond_to(:connection?)
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

  describe ".server?" do
    it "returns false" do
      expect(described_class.server?).to eq(false)
    end

    context "when `CLI` is loaded" do
      before do
        load "harmoniser/cli.rb"
      end

      it "returns true" do
        expect(described_class.server?).to eq(true)
      end
    end
  end
end
