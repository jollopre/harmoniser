# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Harmoniser is a Ruby gem that provides a minimalistic, thread-safe approach to interacting with RabbitMQ (AMQP 0-9-1 implementation) using the Bunny library. It simplifies message publishing and consuming in Ruby applications.

**Key Concepts:**
- **Publishers**: Classes that include `Harmoniser::Publisher` module for sending messages to RabbitMQ exchanges
- **Subscribers**: Classes that include `Harmoniser::Subscriber` module for consuming messages from RabbitMQ queues
- **Topology Definition**: Declarative approach to defining exchanges, queues, and bindings separate from business logic
- **CLI Server**: Dedicated process (`bundle exec harmoniser`) for running message subscribers

## Development Commands

**Setup and Build:**
```bash
make build          # Build Docker containers (no cache)
make install        # Install gem dependencies
make up            # Start all services (RabbitMQ + dependencies)
make down          # Stop all services
```

**Testing:**
```bash
make test          # Run RSpec tests (starts dependencies first)
make start_dependencies  # Start only RabbitMQ dependency
```

**Code Quality:**
```bash
make lint          # Run StandardRB linter
make lint_fix      # Auto-fix linting issues
```

**Development Environment:**
```bash
make shell         # Access gem development container
make shell-payments # Access payments example container
make logs          # View container logs
make clean         # Clean up containers and volumes
```

**Running Examples:**
```bash
# Run the CLI with example files
bundle exec harmoniser --require ./examples/multicast.rb
bundle exec harmoniser --require ./examples/broadcast.rb
```

## Architecture

### Core Modules

**lib/harmoniser.rb** - Main entry point that extends `Configurable` and `Loggable`

**lib/harmoniser/publisher.rb** - Mixin module for classes that publish messages:
- Thread-safe publishing with per-class mutex
- Lazy exchange creation with passive declaration
- Built-in return handling for undeliverable messages

**lib/harmoniser/subscriber.rb** - Mixin module for classes that consume messages:
- Automatic registration with subscriber registry
- Consumer lifecycle management (start/stop)
- Default and custom message/cancellation handlers

**lib/harmoniser/connectable.rb** - Shared connection management for publishers/subscribers

**lib/harmoniser/topology.rb** - Declarative topology definition (exchanges, queues, bindings)

### Configuration Pattern

Harmoniser uses a centralized configuration block:

```ruby
Harmoniser.configure do |config|
  # Connection settings
  config.connection_opts = { host: "rabbitmq" }

  # Topology definition (separate from business logic)
  config.define_topology do |topology|
    topology.add_exchange(:topic, "my_exchange")
    topology.add_queue("my_queue")
    topology.add_binding("my_exchange", "my_queue", routing_key: "pattern.*")
    topology.declare
  end
end
```

### Thread-Safety

- Each publisher/subscriber class gets its own `HARMONISER_*_MUTEX`
- Connection and channel management is thread-safe
- Designed to work with multi-threaded Ruby servers (Puma, Sidekiq, etc.)

### CLI Architecture

**bin/harmoniser** - Executable that loads `Harmoniser::CLI`
- Starts dedicated server process for subscribers
- Handles signal management (SIGINT, SIGTERM)
- Uses subscriber registry to discover and manage consumers

**lib/harmoniser/launcher/** - Different concurrency models:
- `Bounded` - Limited worker threads
- `Unbounded` - Dynamic thread management

## Testing

**Framework**: RSpec with Docker-based testing
**Test Setup**: `spec/spec_helper.rb` configures RabbitMQ connection for tests
**Environment**: Uses `RABBITMQ_HOST` environment variable (defaults to 127.0.0.1)

**Key Testing Patterns:**
- Mock implementations available in `lib/harmoniser/mock/`
- Examples serve as integration test scenarios
- Tests run in isolated Docker environment

## Examples Structure

**examples/multicast.rb** - Complete publisher/subscriber example with topology
**examples/payments/** - Full Rails application demonstrating integration

## Important Implementation Details

### Publisher Pattern
```ruby
class MyPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_exchange"
end

MyPublisher.publish(payload, routing_key: "key")
```

### Subscriber Pattern
```ruby
class MySubscriber
  include Harmoniser::Subscriber
  harmoniser_subscriber queue_name: "my_queue"

  def self.on_delivery(delivery_info, properties, payload)
    # Handle message
  end
end
```

### Mock Mode Support
The gem includes mock implementations for testing without RabbitMQ infrastructure.

## Ruby Version Requirements

- **Minimum Ruby**: 3.2+
- **Runtime Dependency**: bunny ~> 2.24
- **Development Tools**: StandardRB for linting, RSpec for testing