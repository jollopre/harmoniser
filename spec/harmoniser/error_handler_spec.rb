require "harmoniser/error_handler"

RSpec.describe Harmoniser::ErrorHandler do
  describe "#on_error" do
    subject { described_class.new }

    it "appends the error handler to the list of error handlers" do
      handler = proc { |error, ctx| }

      subject.on_error(handler)

      expect(subject.instance_variable_get(:@handlers)).to include(handler)
    end

    it "appends a block to the list of error handlers" do
      block = proc { |error, ctx| }

      subject.on_error(&block)

      expect(subject.instance_variable_get(:@handlers)).to include(block)
    end

    context "when no handler or block is passed" do
      it "raises ArgumentError" do
        expect do
          subject.on_error
        end.to raise_error(ArgumentError, "Please, provide a handler or a block")
      end
    end

    context "when handler is passed bues not respond to call" do
      it "raises TypeError" do
        expect do
          subject.on_error(Object.new)
        end.to raise_error(TypeError, "Handler must respond to call")
      end
    end
  end

  describe "#handle_error" do
    subject { described_class.new }
    let(:exception) { StandardError.new("An error occurred") }
    let(:ctx) { {description: "Something happened"} }
    let(:handler1) { proc { |e, c| puts "Handler 1: #{e.detailed_message}, Context: #{c}" } }
    let(:handler2) { proc { |e, c| puts "Handler 2: #{e.detailed_message}, Context: #{c}" } }

    before do
      subject.on_error(handler1)
      subject.on_error(handler2)
    end

    it "executes every error_handler defined" do
      expect(handler1).to receive(:call).with(exception, ctx).and_call_original
      expect(handler2).to receive(:call).with(exception, ctx).and_call_original

      subject.handle_error(exception, ctx)
    end

    context "when any error handler defined raises an error" do
      let(:handler1) { proc { |e, c| raise "boom!" } }

      it "ignores it and continues executing the rest of the handlers" do
        expect(handler1).to receive(:call).with(exception, ctx).and_call_original
        expect(handler2).to receive(:call).with(exception, ctx).and_call_original

        subject.handle_error(exception, ctx)
      end

      it "reports the error from the handler" do
        expect do
          subject.handle_error(exception, ctx)
        end.to output(/An error occurred while handling a previous error/).to_stderr_from_any_process
      end
    end

    context "when timeout is met while executing the handlers" do
      let(:call_counter) { [] }
      let(:handler1) {
        proc { |e, c|
          call_counter.push(true)
          sleep(1)
        }
      }
      let(:handler2) { proc { |e, c| call_counter.push(true) } }
      before do
        stub_const("Harmoniser::ErrorHandler::TIMEOUT", 0.1)
      end

      it "interrupts the execution" do
        subject.handle_error(exception, ctx)

        expect(call_counter.size).to eq(1)
      end
    end
  end
end
