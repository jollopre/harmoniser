# Changelog

## [0.10.0] - 2024-09-16

### Added
- Add a concurrency option to the CLI. By default, concurrency is unbounded, i.e., each subscriber
  has its own thread dedicated to processing messages
- Introduce Harmoniser::Subscriber::Registry for holding references to classes that include
  Harmoniser::Subscriber
- Kill the process when an ACK timeout is received through any channel. The process terminates with
  exit code 138
- Add a 25-second timeout to shut down the process. This is only applicable to processes using the
  concurrency option

### Changed
- Update Bunny to the latest version, i.e., 2.23
- Cancel subscribers and connection is done within the Launcher context instead of relying on
  at_exit hook
- Prevent the connection from being closed after Topology#declare finishes; only the channel used
  is closed

## [0.9.0] - 2024-08-09

### Added
- Add debug log when a message is received by a subscriber
- Add error_class, error_message and error_backtrace for `--require` option from cli

### Changed
- Amend debug log when a message is published so that exchange name is included
- Improve error message for MissingExchangeDefinition and
  MissingConsumerDefinition
- Define dev dependencies through Gemfile instead of gemspec
- Changed Topology methods to return self so that Topology definition becomes chainable

## [0.8.1] - 2024-04-08

### Fixed
- Exit ruby process when harmoniser is not the main process. More details at [issue](https://github.com/jollopre/harmoniser/issues/41).

## [0.8.0] - 2024-03-31

### Added
- Implement retry mechanism to establish connection to RabbitMQ. More details at [issue](https://github.com/jollopre/harmoniser/issues/39).
- Strengthen at_exit hook to not break when connection cannot be closed.

## [0.7.0] - 2024-01-03

### Added
- Add a default on_return callback for Publisher. When a message marked as mandatory is published and cannot be routed to any queue, a detailed log is output.

### Changed
- Improve README to highlight Harmoniser golden features
- Shorten the gemspec summary

### Removed
- Delete docs folder since github wiki is the way to document the library.
- Delete .travis.yml since we no longer use for CI/CD integration.

## [0.6.0] - 2023-12-30

### Added
- Create a channel for each class including Harmoniser::Publisher or Harmoniser::Subscriber. A mutex in the context of the class including Publisher or Subscriber modules control access to the resources created as well as guarantees safe publication under multi-thread process.
- Introduce broadcast and unicast examples.
- Amend specs to wipe out RabbitMQ resources created during spec execution.

### Changed
- Honour verbose option regardless of the environment configuration set. For instance, for non-production environment, verbose is no longer verbose set by default.

## [0.5.0] - 2023-12-20

### Added
- Setup at_exit hook to be executed when Harmoniser exits for an opened RabbitMQ connection
- Add defaults to Bunny::Session for timeouts and recovery attempts
- Fix boot up problems for payments application example
- Perform refactoring of internals such as slimming down Configuration

## [0.4.0] - 2023-12-07

### Added
- Default logger with error severity for when errors occur at channel level
- Default logger with error severity for when errors occur while processing a message from a queue

### Removed
- Unused docker image for rabbitMQ (only for development purposes)

## [0.3.0] - 2023-11-29

### Added

- Introduce github action for building, linting and running specs anytime a pull request is opened or push to master happens

## [0.2.0] - 2023-11-28

### Added

- Introduce github action for releasing the gem once is merged into master

## [0.1.0] - 2023-11-27

### Added

- Support to express publishing through any kind of exchanges
- Capability to subscribe to queues
- Express RabbitMQ topology separated from the responsibility of publishing or subscribing
- Provide dedicated Ruby process to consume messages through the subscribers defined
