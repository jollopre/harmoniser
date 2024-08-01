require "forwardable"
require "bunny"

module Harmoniser
  class Connection
    extend Forwardable

    DEFAULT_CONNECTION_OPTS = {
      connection_name: "harmoniser@#{VERSION}",
      connection_timeout: 5,
      host: "127.0.0.1",
      password: "guest",
      port: 5672,
      read_timeout: 5,
      tls_silence_warnings: true,
      username: "guest",
      verify_peer: false,
      vhost: "/",
      write_timeout: 5
    }

    def_delegators :@bunny, :create_channel, :open?, :recovering_from_network_failure?

    def initialize(opts)
      @bunny = Bunny.new(opts)
    end

    def to_s
      "<#{self.class.name}>: #{user}@#{host}:#{port}, connection_name = `#{connection_name}`, vhost = `#{vhost}`"
    end

    # TODO Only perform retries when Harmoniser.server?
    def start
      retries = 0
      begin
        with_signal_handler { @bunny.start }
      rescue => e
        Harmoniser.logger.error("Connection attempt failed: retries = `#{retries}`, error_class = `#{e.class}`, error_message = `#{e.message}`")
        with_signal_handler { sleep(1) }
        retries += 1
        retry
      end
    end

    def close
      @bunny.close
      true
    rescue => e
      Harmoniser.logger.error("Connection#close failed: error_class = `#{e.class}`, error_message = `#{e.message}`")
      false
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

    # TODO Use Signal handler defined at Harmoniser::CLI instead of rescuing SignalException?
    def with_signal_handler
      yield if block_given?
    rescue SignalException => e
      Harmoniser.logger.info("Signal received: signal = `#{Signal.signame(e.signo)}`")
      Harmoniser.server? ? exit(0) : raise
    end
  end
end
