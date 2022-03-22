require "harmoniser/configuration"

RSpec.describe Harmoniser::Configuration do
  describe "#bunny=" do
    subject { described_class.new }

    context "when hash of options is passed" do
      before do
        allow(Bunny).to receive(:new)
      end

      it "forward them to Bunny" do
        subject.bunny = {host: "a_host", port: "a_port", user: "wadus", pass: "S3cret_password", vhost: "/"}

        expect(Bunny).to have_received(:new).with(
          host: "a_host",
          port: "a_port",
          user: "wadus",
          pass: "S3cret_password",
          vhost: "/",
          logger: subject.logger
        )
      end

      context "but includes logger" do
        it "respect logger option passed" do
          logger = Logger.new(IO::NULL)

          subject.bunny = {host: "a_host", port: "a_port", user: "wadus", pass: "S3cret_password", vhost: "/", logger: logger}

          expect(Bunny).to have_received(:new).with(
            include(logger: logger)
          )
        end
      end
    end

    context "when Bunny instance is passed" do
      it "set bunny instance variable" do
        subject.bunny = Bunny.new({})

        expect(subject.bunny).to be_an_instance_of(Bunny::Session)
      end
    end

    it "raises ArgumentError" do
      expect do
        subject.bunny = nil
      end.to raise_error(ArgumentError, "Hash or Bunny argument is expected")
    end
  end
end
