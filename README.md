# Harmoniser

[![Gem Version](https://badge.fury.io/rb/harmoniser.svg)](https://badge.fury.io/rb/harmoniser)
![CI workflow](https://github.com/jollopre/harmoniser/actions/workflows/ci.yml/badge.svg)

A minimalistic approach to communicating with RabbitMQ.

Harmoniser uses [Bunny](https://github.com/ruby-amqp/bunny) as a low level library to communicate with RabbitMQ in order to integrate publishing and messages consuming.

## Getting Started

1. Add this line to your application's Gemfile:

```ruby
gem "harmoniser"
```

2. Install the gem:

```ruby
  $ bundle install
```

3. Include `Harmoniser::Publisher` and/or `Harmoniser::Subscriber` in your classes. For instance, [this scenario](examples/multicast.rb) assumes that you'd like to run publishers and subscriber under the same process.

4. (Optional) Run the dedicated process for Harmoniser in order to process messages from your subscribers:

```sh
  $ bundle exec harmoniser --require ./examples/multicast.rb
```

5. Inspect the logs to see if everything worked as expected. Look for logs including `harmoniser@`.

## Concepts

Harmoniser is a library for publishing/consuming messages through RabbitMQ. It allows to not only connect applications but also to scale an application by performing work in the background. This gem is comprised of three parts:

### Publisher

The Publisher runs in any Ruby process (puma, unicorn, passenger, sidekiq, etc) and allows you to
push messages through a [RabbitMQ Exchange](https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchanges). Creating a publisher is as simple as:

```ruby
require "harmoniser"

class MyPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_topic_exchange"
end

MyPublisher.publish({ salute: "Hello World!" }.to_json, routing_key: "my_resource.foo.bar")
```

The code above assumes that the exchange is already defined. We'd like to emphasize that defining RabbitMQ topology (exchanges, queues and binding) should be performed outside of the class whose role is purely focused on publishing. See more details about how to define the topology [here](examples/multicast.rb#L9-L18).

### RabbitMQ

RabbitMQ is the message broker used to publish/consume messages through Harmoniser. It can be configured through `Harmoniser.configure` as follows:

```ruby
require "harmoniser"

Harmoniser.configure do |config|
  config.connection_opts = {
    host: "rabbitmq"
  }
end
```

The options permitted for `connection_opts` are those accepted by
[Bunny](https://github.com/ruby-amqp/bunny/blob/80a8fc7aa0cd73f8778df87ae05f28c443d10c0d/lib/bunny/session.rb#L142) since at the end this library is built on top of the most widely used Ruby client for RabbitMQ.

### Subscriber Server

Harmoniser server is a process specifically dedicated to run Subscribers that are listening into [Rabbit Queues](https://www.rabbitmq.com/tutorials/amqp-concepts.html#queues). This process like any other Ruby process (puma, unicorn, passenger, sidekiq, etc) is up and running unless OS Signals like (SIGINT, SIGTERM) are sent to it. The server during boot time is able to register each class from your code that includes `Harmoniser::Subscriber` module. Creating a subscriber is as simple as:

```ruby
class MySubscriber
  include Harmoniser::Subscriber
  harmoniser_subscriber queue_name: "my_queue"

  class << self
    def on_delivery(delivery_info, properties, payload)
      Harmoniser.logger.info({
        body: "message received",
        payload: payload
      }.to_json)
    end
  end
end
```

The code above assumes that the queue and its binding to an exchange are already defined. You can see more details about how this is specified [here](examples/multicast.rb#L9-L18).

In order for the subscribers to receive messages from a queue, you should spin up a dedicated Ruby process like following:

```sh
  $ bundle exec harmoniser --require ./a_path_to_your_ruby_file.rb
```

More info about the different options accepted by harmoniser process in [Harmoniser CLI](docs/cli.md).

## Contributing

If you are facing issues and you suspect are related to Harmoniser, please consider opening an issue [here](https://github.com/jollopre/harmoniser/issues). Remember to include as much information as possible such as version of Ruby, Rails, Harmoniser, OS, etc.

If you consider you have encountered a potential bug, detailed information about how to reproduce it might help to speed up its fix.

### Code

In order to contribute to this codebase, you will need to setup your local development using the following steps:

```sh
# Prepare the environment for working locally.
  $ make build
# Perform the desired changes into your local copy
  $ make test
```

You can also shell into the running container by executing `$ make shell` and from within execute anything related to Harmoniser on its isolated environment.

## Future Improvements

- [ ] Issue: Reopen memoized Channel in the context of the class that are included. There are scenarios for which the channel gets closed, for instance Precondition Failed when checking an exchange declaration.
- [ ] Chore: Introduce simplecov gem for code coverage.
- [ ] Feature: Add sensible defaults for Session options like heartbeat, timeout, recovery_completed or recovery_attempt_started.
- [ ] Feature: Add default `on_return` handler as well as permitting the definition of on_return method to be called anytime a published message gets returned.
- [ ] Feature: Introduce capability of configuring number of threads for queue consuming at the CLI.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Author

Jose Lloret, [<jollopre@gmail.com>](mailto:jollopre@gmail.com)
