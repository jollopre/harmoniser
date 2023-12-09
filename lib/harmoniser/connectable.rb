require "harmoniser/connection"

module Harmoniser
  module Connectable
    MUTEX = Mutex.new

    def connection_opts
      @connection_opts ||= Connection::DEFAULT_CONNECTION_OPTS.merge({logger: Harmoniser.logger})
    end

    def connection_opts=(opts)
      raise TypeError, "opts must be a Hash object" unless opts.is_a?(Hash)

      @connection_opts = connection_opts.merge(opts)
    end

    def connection
      MUTEX.synchronize do
        @connection ||= create_connection
        @connection.start unless @connection.open? || @connection.recovering_from_network_failure?
        @connection
      end
    end

    def connection?
      !!defined?(@connection)
    end

    private

    def create_connection
      at_exit(&method(:at_exit_handler).to_proc)
      Connection.new(connection_opts)
    end

    def at_exit_handler
      logger = Harmoniser.logger

      logger.info("Shutting down!")
      if connection? && connection.open?
        stringified_connection = connection.to_s
        logger.info("Connection will be closed: connection = `#{stringified_connection}`")
        connection.close
        logger.info("Connection closed: connection = `#{stringified_connection}`")
      end
      logger.info("Bye!")
    end
  end
end
