# Harmoniser

A friendly approach to RabbitMQ using the power of Bunny underneath

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'harmoniser'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install harmoniser

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Roadmap

- Add other properties to DEFAULT_CONNECTION_OPTS like heartbeat, connection_timeout,
  read_timeout, write_timeout, recovery_completed, recovery_attempt_started, connection_name
- Explore if Exchange#on_return might be proxied through Harmoniser::Publisher
- Evaluate if there is any benefit on using Channel#synchronize instead of a mutex for each publication
- Explore if Channel#on_error or Channel#on_uncaught_exception should be proxied through Harmoniser::Publisher or Harmoniser::Subscriber

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
