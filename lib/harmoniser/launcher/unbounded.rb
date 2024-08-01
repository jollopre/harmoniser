require_relative "base"

module Harmoniser
  module Launcher
    class UnBounded < Base
      def start_subscribers
        @consumers = subscribers.map(&:harmoniser_subscriber_start)
      end
    end
  end
end
