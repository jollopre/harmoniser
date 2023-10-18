require "securerandom"

module Harmoniser
  ConnectionOpts = Data.define(
    :connection_name,
    :host,
    :password,
    :port,
    :tls_silence_warnings,
    :username,
    :verify_peer,
    :vhost
  )

  DEFAULT_CONNECTION_OPTS = ConnectionOpts.new(
    connection_name: "harmoniser@#{VERSION}-#{SecureRandom.uuid}",
    host: "127.0.0.1",
    password: "guest",
    port: 5672,
    tls_silence_warnings: true,
    username: "guest",
    verify_peer: false,
    vhost: "/"
  )
end
