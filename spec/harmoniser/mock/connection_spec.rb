# frozen_string_literal: true

require "harmoniser/mock/connection"

RSpec.describe Harmoniser::Mock::Connection do
  let(:opts) { {host: "localhost", port: 5672} }
  let(:error_handler) { double("error_handler") }
  let(:logger) { double("logger") }
  let(:connection) { described_class.new(opts, error_handler: error_handler, logger: logger) }

  describe "#initialize" do
    it "accepts opts, error_handler, and logger parameters" do
      expect { connection }.not_to raise_error
    end

    it "works with minimal parameters" do
      minimal_connection = described_class.new

      expect(minimal_connection).to be_a(described_class)
    end

    it "works with only opts parameter" do
      opts_only_connection = described_class.new(opts)

      expect(opts_only_connection).to be_a(described_class)
    end
  end

  describe "#create_channel" do
    it "returns a Harmoniser::Mock::Channel instance" do
      result = connection.create_channel

      expect(result).to be_a(Harmoniser::Mock::Channel)
    end

    it "accepts all expected parameters" do
      result = connection.create_channel("channel_id", 5, true, 120)

      expect(result).to be_a(Harmoniser::Mock::Channel)
    end

    it "works with default parameters" do
      result = connection.create_channel

      expect(result).to be_a(Harmoniser::Mock::Channel)
    end

    it "works with partial parameters" do
      result = connection.create_channel(nil, 3)

      expect(result).to be_a(Harmoniser::Mock::Channel)
    end

    it "returns different Channel instances on each call" do
      channel1 = connection.create_channel
      channel2 = connection.create_channel

      expect(channel1).not_to be(channel2)
      expect(channel1).to be_a(Harmoniser::Mock::Channel)
      expect(channel2).to be_a(Harmoniser::Mock::Channel)
    end
  end

  describe "#open?" do
    it "returns false initially" do
      expect(connection.open?).to be(false)
    end

    it "returns true after start is called" do
      connection.start
      expect(connection.open?).to be(true)
    end

    it "returns false after close is called" do
      connection.start
      connection.close
      expect(connection.open?).to be(false)
    end

    it "reflects actual connection state" do
      expect(connection.open?).to be(false)

      connection.start
      expect(connection.open?).to be(true)

      connection.close
      expect(connection.open?).to be(false)

      connection.start
      expect(connection.open?).to be(true)
    end
  end

  describe "#recovering_from_network_failure?" do
    it "returns false" do
      expect(connection.recovering_from_network_failure?).to be(false)
    end

    it "always returns false regardless of internal state" do
      connection.start
      connection.close
      expect(connection.recovering_from_network_failure?).to be(false)
    end
  end

  describe "#start" do
    it "returns self" do
      result = connection.start

      expect(result).to be(connection)
    end

    it "can be called multiple times" do
      expect { connection.start.start.start }.not_to raise_error
    end
  end

  describe "#close" do
    it "returns true" do
      result = connection.close

      expect(result).to be(true)
    end

    it "can be called multiple times" do
      expect(connection.close).to be(true)
      expect(connection.close).to be(true)
    end

    it "can be called even without calling start first" do
      fresh_connection = described_class.new

      expect(fresh_connection.close).to be(true)
    end
  end

  describe "method chaining" do
    it "allows start to be chained" do
      result = connection.start.create_channel

      expect(result).to be_a(Harmoniser::Mock::Channel)
    end
  end

  describe "state behavior" do
    it "open? reflects start/close state while recovering_from_network_failure? remains constant" do
      expect(connection.open?).to be(false)
      expect(connection.recovering_from_network_failure?).to be(false)

      connection.start
      expect(connection.open?).to be(true)
      expect(connection.recovering_from_network_failure?).to be(false)

      connection.close
      expect(connection.open?).to be(false)
      expect(connection.recovering_from_network_failure?).to be(false)
    end
  end
end
