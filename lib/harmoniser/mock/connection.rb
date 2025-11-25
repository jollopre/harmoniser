# frozen_string_literal: true

require "harmoniser/mock/channel"

module Harmoniser
  module Mock
    class Connection
      def initialize(opts = {}, error_handler: nil, logger: nil)
        @opts = opts
        @error_handler = error_handler
        @logger = logger
        @open = false
      end

      def create_channel(id = nil, consumer_pool_size = 1, consumer_pool_ack = false, consumer_pool_shutdown_timeout = 60)
        Channel.new
      end

      def open?
        @open
      end

      def recovering_from_network_failure?
        false
      end

      def start
        @open = true
        self
      end

      def close
        @open = false
        true
      end
    end
  end
end
