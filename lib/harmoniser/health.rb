require "socket"

module Harmoniser
  module Health
    class Error < StandardError ; end
    class Server
      def initialize(path: "/tmp/harmoniser.sock")
        @path = path
      end

      def call
        Thread.new do
          File.delete(@path) if File.exist?(@path)

          server = UNIXServer.new(@path)

          loop do
            client = server.accept
            message = client.gets.chomp
            Harmoniser.logger.debug("Received `#{message}`")
            if message == "ping"
              client.puts("pong")
            else
              client.puts("Unknown command")
            end
            client.close
          end
        end.tap do |t|
          t.abort_on_exception = true
          t.report_on_exception = false
        end
      end
    end

    class Client
      def initialize(path: "/tmp/harmoniser.sock")
        @path = path
      end

      def ping
        socket = UNIXSocket.new(@path)
        socket.puts("ping")
        socket.gets.chomp
        socket.close
        response
      rescue
        raise Error
      end
    end
  end
end
