# frozen_string_literal: true

module Harmoniser
  module Mock
    class Channel
      class MockExchange
        attr_reader :name, :type, :opts

        def initialize(name, opts = {})
          @name = name
          @type = opts[:type]
          @opts = opts.except(:type)
          @published_messages = []
          @return_handler = nil
        end

        def publish(payload, opts = {})
          @published_messages << {payload: payload, opts: opts}
          true
        end

        def on_return(&block)
          @return_handler = block
          self
        end

        def published_messages
          @published_messages.dup
        end

        def reset!
          @published_messages.clear
          @return_handler = nil
        end
      end

      class MockQueue
        attr_reader :name, :opts

        def initialize(name, opts = {})
          @name = name
          @opts = opts
        end
      end

      def initialize
        @exchanges = {}
        @queues = {}
        @bindings = []
      end

      def exchange(name, opts = {})
        @exchanges[name] ||= MockExchange.new(name, opts)
      end

      def queue(name, opts = {})
        @queues[name] ||= MockQueue.new(name, opts)
      end

      def queue_bind(destination_name, exchange_name, opts = {})
        @bindings << {
          destination_name: destination_name,
          exchange_name: exchange_name,
          opts: opts
        }
        true
      end

      def exchanges
        @exchanges.dup
      end

      def queues
        @queues.dup
      end

      def bindings
        @bindings.dup
      end

      def reset!
        @exchanges.clear
        @queues.clear
        @bindings.clear
      end

      def bunny_channel
        raise "Cannot access bunny_channel in mock mode. Mock mode is intended for testing only and cannot be used when running Harmoniser as a server process."
      end
    end
  end
end
