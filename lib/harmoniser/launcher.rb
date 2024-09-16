require_relative "launcher/bounded"
require_relative "launcher/unbounded"

module Harmoniser
  module Launcher
    class << self
      def call(configuration:, logger:)
        return Bounded.new(configuration:, logger:) unless configuration.options.unbounded_concurrency?

        UnBounded.new(configuration:, logger:)
      end
    end
  end
end
