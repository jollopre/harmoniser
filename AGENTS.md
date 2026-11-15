# AGENTS.md

## What

Harmoniser is a Ruby gem (Ruby >= 3.2, MIT) that offers a minimalistic, declarative way to publish and consume messages through RabbitMQ (AMQP 0-9-1). It is built on top of [Bunny](https://github.com/ruby-amqp/bunny) (`~> 2.24`), which is its only runtime dependency.

It is made up of four pieces:

- **Configuration** (`Harmoniser.configure`): connection options (any [Bunny connection option](https://github.com/ruby-amqp/bunny/blob/main/docs/guides/connecting.md#using-a-map-of-parameters), merged over `Connection::DEFAULT_CONNECTION_OPTS`), topology definition (`define_topology`) and error handlers (`on_error`).
- **Topology** (`lib/harmoniser/topology.rb`): declares exchanges, queues and bindings, kept apart from the classes that publish or consume.
- **Publisher** (`include Harmoniser::Publisher`): publishes to an exchange that already exists. It runs in any Ruby process (Puma, Unicorn, Sidekiq, etc.).
- **Subscriber + Server** (`include Harmoniser::Subscriber`, `bin/harmoniser`): subscribers register themselves in `Subscriber.registry` when included. The `harmoniser` CLI (`lib/harmoniser/cli.rb`) boots the app (a single file, or a Rails app when `--require` points to a directory), starts every registered subscriber and keeps running until it gets `INT`/`TERM`/`USR1`. Options: `-c/--concurrency`, `-e/--environment`, `-r/--require`, `-v/--verbose`, `-V`, `-h`.

Key internals:

- `Connectable`: one lazily created, mutex-guarded connection per role. Publisher, Subscriber and Topology each get their own connection.
- `Channel`: wraps `Bunny::Channel`, attaches `on_error`/`on_uncaught_exception` callbacks and cancels consumers before closing. Every channel is registered on its `Connection` so it can be closed first.
- `Launcher::UnBounded` (the default, concurrency = infinity) gives each subscriber its own channel and thread. `Launcher::Bounded` (`-c N`) shares one channel whose consumer work pool has N threads and a `timeout` for shutdown.
- `ErrorHandler`: a chain of `call`-able handlers that runs on a separate thread with a 25 s timeout. The default handler logs.
- `Mock` (`require "harmoniser/mock"; Harmoniser::Mock.mock!`): swaps connections and channels for in-memory fakes. Mock exchanges record `published_messages`, so tests can run without a broker.
- Logs go to `$stdout` with progname `harmoniser@<version>`.

## Why

Bunny is a solid, low-level AMQP client, but it leaves the following to each application. Harmoniser handles them:

| Bunny leaves you to... | Harmoniser provides |
|---|---|
| Share channels across threads safely yourself (Bunny channels are not thread-safe) | One dedicated channel per publisher/subscriber class, with publishing serialised by a mutex in each class |
| Mix topology declaration into publishing and consuming code | A topology DSL in configuration. Publishers declare exchanges `passive: true`, so they never create topology |
| Write your own long-running consumer process, signal handling and app boot | The `harmoniser` CLI: boots plain Ruby or Rails, traps `INT`/`TERM`/`USR1` and shuts down gracefully |
| Handle a failed first connection (Bunny's automatic recovery only works after a connection has been established) | Retries the initial connection when Harmoniser runs as the server process |
| Separate publisher and consumer connections yourself | Separate connections for Publisher, Subscriber and Topology, as RabbitMQ [recommends because of resource alarms](https://www.rabbitmq.com/docs/alarms#effects-on-clusters) |
| React to a channel closed by a delivery-ack timeout (the channel stays dead) | Detects the ack timeout and makes the server exit with code 138 (`USR1`) so a supervisor restarts it |
| Order shutdown correctly | Cancels consumers, closes channels and only then closes the connection, which avoids `Bunny::ConnectionClosedError` from late acks. Logs work-pool backlog stats at shutdown |
| Add observability hooks | Default logging for `on_return`, `on_error`, `on_cancellation`, blocked/unblocked alarms and recovery, plus pluggable `on_error` handlers (e.g. for Sentry) |
| Choose a concurrency model | Unbounded (a thread per subscriber) or bounded (a shared work pool via `-c`) |
| Test without a broker (Bunny ships no test double) | `Harmoniser::Mock` |

## How

```ruby
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {host: "rabbitmq"}
  config.define_topology do |topology|
    topology
      .add_exchange(:topic, "my_topic_exchange", durable: true)
      .add_queue("my_queue", durable: true)
      .add_binding("my_topic_exchange", "my_queue", routing_key: "my_resource.foo.*")
      .declare
  end
  config.on_error { |exception, ctx| warn("#{ctx[:description]}: #{exception.detailed_message}") }
end

class MyPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_topic_exchange"
end

class MySubscriber
  include Harmoniser::Subscriber
  harmoniser_subscriber queue_name: "my_queue" # no_ack: true by default

  def self.on_delivery(delivery_info, properties, payload)
    puts "Received #{payload}"
  end
end

MyPublisher.publish({salute: "Hello World!"}.to_json, routing_key: "my_resource.foo.bar")
```

Run the subscribers with `bundle exec harmoniser --require ./path/to/file.rb` (or `--require .` for a Rails app). More examples live in `examples/` (unicast, multicast, broadcast, on_return, mock, and a Rails app in `examples/payments`).

### Development (Docker-based, via `Makefile`)

| Target | Purpose |
|---|---|
| `make build` | Build images (no cache) |
| `make up` / `make down` | Start the stack (gem, RabbitMQ, payments example) detached / stop it |
| `make test` | Wait for RabbitMQ, then run `bundle exec rspec`. The specs talk to a real RabbitMQ |
| `make lint` / `make lint_fix` | Run `standardrb` / auto-fix |
| `make install` | `bundle install` inside the `gem` container |
| `make shell` / `make shell-payments` | Open a shell in the gem / payments container |
| `make logs` | Show compose logs |
| `make start_dependencies` | Wait until RabbitMQ is reachable |
| `make clean` | Remove containers, images and volumes |

Record every change in `CHANGELOG.md` and bump `lib/harmoniser/version.rb`.
