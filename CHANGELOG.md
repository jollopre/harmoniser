# Changelog

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
