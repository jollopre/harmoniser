require "harmoniser/parser"

RSpec.describe Harmoniser::Parser do
  describe "#call" do
    let(:logger) { Logger.new(STDOUT) }
    subject { described_class.new(logger: logger) }

    context "when -e is received" do
      it "options returned contains `environment` to `production`" do
        result = subject.call(["-e", "production"])

        expect(result).to include(environment: "production")
      end
    end

    context "when -r is received" do
      context "but it is a directory" do
        it "options returned contains `require` to directory where Rails application is located" do
          result = subject.call(["-r", "/opt/my_rails_app"])

          expect(result).to include(require: "/opt/my_rails_app")
        end
      end

      context "but it is a file" do
        it "options returned contains `require` to path of file for running the subscribers" do
          result = subject.call(["-r", "./foo/bar.rb"])

          expect(result).to include(require: "./foo/bar.rb")
        end
      end
    end

    context "when `-v` is received" do
      it "options returned contains `verbose` to true" do
        result = subject.call(["-v"])

        expect(result).to include(verbose: true)
      end
    end

    context "when `-V` is received" do
      it "outputs the version" do
        allow($stdout).to receive(:puts)

        expect do
          subject.call(["-V"])
        end.to output(/Harmoniser #{Harmoniser::VERSION}/).to_stdout
      end
    end

    context "when `-h` is received" do
      it "outputs the different options accepted for parsing" do
        allow($stdout).to receive(:puts)

        expect do
          subject.call(["-h"])
        end.to output(/harmoniser \[options\]/).to_stdout
      end
    end

    context "when invalid option is received" do
      it "raises" do
        expect do
          subject.call(["-wtf"])
        end.to raise_error(OptionParser::InvalidOption)
      end
    end
  end
end
