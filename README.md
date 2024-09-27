# Harmoniser

[![Gem Version](https://badge.fury.io/rb/harmoniser.svg)](https://badge.fury.io/rb/harmoniser)
![CI workflow](https://github.com/jollopre/harmoniser/actions/workflows/ci.yml/badge.svg)

Harmoniser is a minimalistic approach to interact with the RabbitMQ implementation of [AMQP 0-9-1](https://www.rabbitmq.com/amqp-0-9-1-reference.html) through [Bunny](https://github.com/ruby-amqp/bunny).

* Harmoniser provides a long-lived [connection](https://www.rabbitmq.com/connections.html) to RabbitMQ for efficient publishing and consuming of messages.
* Harmoniser issues a thread-safe dedicated [channel](https://www.rabbitmq.com/channels.html) for each publish/consume use case defined.
* Harmoniser offers a concise DSL to differentiate topology definition from other actions such as publishing or consuming.
* Harmoniser may run as a dedicated Ruby Process through its [CLI](https://github.com/jollopre/harmoniser/wiki/Harmoniser-CLI) as well as a part of other processes like Puma, Unicorn, Sidekiq, or similar.

## Getting Started

1. Add this line to your application's Gemfile:

```ruby
gem "harmoniser"
```

2. Install the gem:

```sh
  $ bundle install
```

3. Include `Harmoniser::Publisher` and/or `Harmoniser::Subscriber` in your classes. For instance, in [this scenario](examples/multicast.rb), it is assumed that you would like to run publishers and subscribers under the same process.

4. (Optional) Run Harmoniser CLI in order to process messages from your subscribers:

```sh
  $ bundle exec harmoniser --require ./examples/multicast.rb
```

5. Inspect the logs to see if everything worked as expected. Look for logs containing `harmoniser@`.

## Concepts

Harmoniser is a library for publishing/consuming messages through RabbitMQ. It enables not only the connection of applications but also the scaling of an application by performing work in the background. This gem is comprised of three parts:

### Publisher

The Publisher runs in any Ruby process (puma, unicorn, passenger, sidekiq, etc) and enables you to push messages through a [RabbitMQ Exchange](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchanges). Creating a publisher is as simple as:

```ruby
require "harmoniser"

class MyPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_topic_exchange"
end

MyPublisher.publish({ salute: "Hello World!" }.to_json, routing_key: "my_resource.foo.bar")
```

The code above assumes that the exchange is already defined. We would like to emphasize that defining RabbitMQ topology (exchanges, queues and bindings) should be performed outside of the class whose role is purely focused on publishing. For more details on how to define the topology, refer to [this example](examples/multicast.rb#L11-L19).

### RabbitMQ

RabbitMQ is the message broker used to publish/consume messages through Harmoniser. It can be configured using `Harmoniser.configure` as follows:

```ruby
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
end
```

The options permitted for `connection_opts` are those accepted by [Bunny](https://github.com/ruby-amqp/bunny/blob/main/docs/guides/connecting.md#using-a-map-of-parameters) since Harmoniser is built on top of the widely used Ruby client for RabbitMQ.

### Harmoniser Server

Harmoniser server is a process specifically dedicated to running Subscribers that listen to [Rabbit Queues](https://www.rabbitmq.com/tutorials/amqp-concepts.html#queues). Like any other Ruby process (puma, unicorn, passenger, sidekiq, etc), Harmoniser remains up and running unless OS Signals such as SIGINT or SIGTERM  are sent to it. During boot time, the server can register each class from your code that includes `Harmoniser::Subscriber` module. Creating a subscriber is as simple as:

```ruby
class MySubscriber
  include Harmoniser::Subscriber
  harmoniser_subscriber queue_name: "my_queue"
end
```

The code above assumes that the queue and its binding to an exchange are already defined. You can find more details about how this is specified [here](examples/multicast.rb#L11-L19).

To enable subscribers to receive messages from a queue, you should spin up a dedicated Ruby process as follows:

```sh
  $ bundle exec harmoniser --require ./a_path_to_your_ruby_file.rb
```

For more information about the various options accepted by the Harmoniser process, refer to the [Harmoniser CLI documentation](https://github.com/jollopre/harmoniser/wiki/Harmoniser-CLI).

## Contributing

If you are facing issues that you suspect are related to Harmoniser, please consider opening an issue [here](https://github.com/jollopre/harmoniser/issues). Remember to include as much information as possible such as version of Ruby, Rails, Harmoniser, OS, etc.

If you believe you have encountered a potential bug, providing detailed information about how to reproduce it can greatly expedite the fix.

### Code

To contribute to this codebase, you will need to setup your local development using the following steps:

```sh
# Prepare the environment for working locally.
  $ make build
# Perform the desired changes into your local copy
  $ make test
```

You can also access the running container by executing `$ make shell` and then execute any commands related to Harmoniser within its isolated environment.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Author

Jose Lloret, [<jollopre@gmail.com>](mailto:jollopre@gmail.com)
