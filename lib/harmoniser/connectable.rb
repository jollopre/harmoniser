require "harmoniser/connection"

module Harmoniser
  module Connectable
    MUTEX = Mutex.new

    def connection_opts
      @connection_opts ||= Connection::DEFAULT_CONNECTION_OPTS
        .merge({
          logger: Harmoniser.logger,
          recovery_attempt_started: proc {
            stringified_connection = connection.to_s
            Harmoniser.logger.info("Recovery attempt started: connection = `#{stringified_connection}`")
          },
          recovery_completed: proc {
            stringified_connection = connection.to_s
            Harmoniser.logger.info("Recovery completed: connection = `#{stringified_connection}`")
          }
        })
    end

    def connection_opts=(opts)
      raise TypeError, "opts must be a Hash object" unless opts.is_a?(Hash)

      @connection_opts = connection_opts.merge(opts)
    end

    def connection
      MUTEX.synchronize do
        @connection ||= Connection.new(connection_opts)
        @connection.start unless @connection.open? || @connection.recovering_from_network_failure?
        @connection
      end
    end

    def connection?
      !!defined?(@connection)
    end
  end
end
