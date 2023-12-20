require "harmoniser/loggable"

RSpec.describe Harmoniser::Loggable do
  subject do
    Class.new do
      extend Harmoniser::Loggable
    end
  end

  describe ".logger" do
    it "returns an instance of Logger" do
      result = subject.logger

      expect(result).to be_an_instance_of(Logger)
    end

    it "logger instance is memoized" do
      result = subject.logger
      result2 = subject.logger

      expect(result.object_id).to eq(result2.object_id)
    end
  end
end
