# Changelog

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
