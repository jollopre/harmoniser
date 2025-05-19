module Harmoniser
  class ErrorHandler
    TIMEOUT = 25
    DEFAULT_ERROR_HANDLER = ->(exception, ctx) do
      Harmoniser.logger.error("Error handler called: exception = `#{exception.detailed_message}`, context = `#{ctx}`")
    end

    class << self
      def default
        @default ||= new([DEFAULT_ERROR_HANDLER])
      end
    end

    def initialize(handlers = [])
      @handlers = handlers
    end

    def on_error(handler = nil, &block)
      h = handler || block
      raise ArgumentError, "Please, provide a handler or a block" if h.nil?
      raise TypeError, "Handler must respond to call" unless h.respond_to?(:call)

      @handlers << h
      self
    end

    def handle_error(exception, ctx = {})
      coordinator = Thread::Queue.new

      Thread.new do
        handlers
          .each { |handler| trigger_handler(handler, exception, ctx) }
          .tap { coordinator.push(true) }
      end.tap do |thread|
        thread.report_on_exception = true
      end

      !!coordinator.pop(timeout: TIMEOUT)
    end

    private

    attr_reader :handlers

    def trigger_handler(handler, exception, ctx)
      handler.call(exception, ctx)
    rescue => e
      warn "An error occurred while handling a previous error: #{e.detailed_message}"
    end
  end
end
