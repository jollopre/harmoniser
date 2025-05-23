require "forwardable"
require "bunny"
require "harmoniser/error_handler"

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

    def initialize(opts, error_handler: ErrorHandler.default, logger: Harmoniser.logger)
      @error_handler = error_handler
      @logger = logger
      @bunny = Bunny.new(maybe_dynamic_opts(opts)).tap do |bunny|
        attach_callbacks(bunny)
      end
    end

    def to_s
      "<#{self.class.name}>:#{object_id} #{user}@#{host}:#{port}, connection_name = `#{connection_name}`, vhost = `#{vhost}`"
    end

    def start
      return @bunny.start unless Harmoniser.server?

      retryable_start
    end

    def retryable_start
      retries = 0
      begin
        @bunny.start
      rescue => e
        handle_error(e, {description: "Connection attempt failed", retries: retries})
        sleep(1)
        retries += 1
        retry
      end
    end

    def close
      @logger.info("Connection will be closed: connection = `#{self}`")
      @bunny.close.tap do
        @logger.info("Connection closed: connection = `#{self}`")
      end
    rescue => e
      handle_error(e, {description: "Connection close failed"})
      false
    end

    private

    def attach_callbacks(bunny)
      bunny.on_blocked do |blocked|
        @logger.warn("Connection blocked: connection = `#{self}`, reason = `#{blocked.reason}`")
      end
      bunny.on_unblocked do |unblocked|
        @logger.info("Connection unblocked: connection = `#{self}`")
      end
    end

    def connection_name
      @bunny.connection_name
    end

    def host
      @bunny.transport.host
    end

    def maybe_dynamic_opts(opts)
      opts.merge({
        logger: opts.fetch(:logger) { @logger },
        recovery_attempt_started: opts.fetch(:recovery_attempt_started) do
          proc { @logger.info("Recovery attempt started: connection = `#{self}`") }
        end,
        recovery_completed: opts.fetch(:recovery_completed) do
          proc { @logger.info("Recovery completed: connection = `#{self}`") }
        end
      })
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

    def handle_error(exception, ctx)
      @error_handler.handle_error(exception, ctx)
    end
  end
end
