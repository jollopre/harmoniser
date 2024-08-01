require "forwardable"

module Harmoniser
  module Subscriber
    class Registry
      extend Forwardable

      def_delegators :@klasses, :<<, :to_a, :each, :map

      def initialize
        @klasses = Set.new
      end

      def to_s
        to_a.map(&:harmoniser_subscriber_to_s).to_s
      end
    end
  end
end
