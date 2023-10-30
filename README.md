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

## Future Improvements

- [ ] Issue: Reopen memoized Channel in the context of the class that are included. There are scenarios for which the channel gets closed, for instance Precondition Failed when checking an exchange declaration.
- [ ] Chore: Introduce simplecov gem for code coverage.
- [ ] Feature: Add sensible defaults for Session options like heartbeat, timeout, recovery_completed or recovery_attempt_started.
- [ ] Feature: Add default `on_return` handler as well as permitting the definition of on_return method to be called anytime a published message gets returned.
- [ ] Feature: Add default `on_error` and `on_uncaught_exception` as well as permitting the definition of them to be called anytime an error in the channel occurs or error in the consumer handler happens.
- [ ] Feature: Introduce capability of configuring number of threads for queue consuming at the CLI.
- [ ] Feature: Define logger levels based on environment option. For instance, when production, the level should be setup as info.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
