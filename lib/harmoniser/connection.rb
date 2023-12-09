require "forwardable"
require "bunny"

module Harmoniser
  class Connection
    extend Forwardable

    DEFAULT_CONNECTION_OPTS = {
      connection_name: "harmoniser@#{VERSION}",
      connection_timout: 5,
      host: "127.0.0.1",
      password: "guest",
      port: 5672,
      read_timeout: 5,
      recovery_attempt_started: proc {
        stringified_connection = Harmoniser.connection.to_s
        Harmoniser.logger.info("Recovery attempt started: connection = `#{stringified_connection}`")
      },
      recovery_completed: proc {
        stringified_connection = Harmoniser.connection.to_s
        Harmoniser.logger.info("Recovery completed: connection = `#{stringified_connection}`")
      },
      tls_silence_warnings: true,
      username: "guest",
      verify_peer: false,
      vhost: "/",
      write_timeout: 5
    }

    def_delegators :@bunny, :close, :create_channel, :open?, :recovering_from_network_failure?, :start

    def initialize(opts)
      @bunny = Bunny.new(opts)
    end

    def to_s
      "<#{self.class.name}>: #{user}@#{host}:#{port}, connection_name = `#{connection_name}`, vhost = `#{vhost}`"
    end

    private

    def connection_name
      @bunny.connection_name
    end

    def host
      @bunny.transport.host
    end

    def port
      @bunny.transport.port
    end

    def user
      @bunny.user
    end

    def vhost
      @bunny.vhost
    end
  end
end
