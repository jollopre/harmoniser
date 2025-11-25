require "bundler/setup"
require "json"
require "harmoniser"
require "harmoniser/mock"

# Enable mock mode for testing
Harmoniser::Mock.mock!

Harmoniser.configure do |config|
  # Configure the connection options for connection to RabbitMQ
  config.connection_opts = {
    host: "rabbitmq"
  }
end

# Create a class that includes Publisher functionality
class TestPublisher
  include Harmoniser::Publisher
  harmoniser_publisher exchange_name: "my_mock_exchange"
end

# Publish multiple messages - each publish returns the exchange instance
exchange = TestPublisher.publish({message: "First test message", timestamp: Time.now}.to_json, routing_key: "test")
TestPublisher.publish({message: "Second test message", data: {id: 123}}.to_json, routing_key: "test")
TestPublisher.publish({message: "Third test message", priority: "high"}.to_json, routing_key: "test")

# Assert published_messages from mocked exchange holds all the publications
published_messages = exchange.published_messages

puts "Published messages count: #{published_messages.length}"
puts "Expected: 3 messages"

# Verify all messages were captured
published_messages.each_with_index do |message, index|
  puts "Message #{index + 1}:"
  puts "  Routing Key: #{message[:routing_key]}"
  puts "  Payload: #{message[:payload]}"
  puts "  Headers: #{message[:headers]}"
  puts ""
end

# Assert that we have exactly 3 messages
raise "Expected 3 messages, got #{published_messages.length}" unless published_messages.length == 3

puts "✓ All assertions passed!"

# Demonstrate reset! functionality
puts "\nTesting reset! - Messages before: #{exchange.published_messages.length}"
exchange.reset!
puts "Messages after reset: #{exchange.published_messages.length}"

# Verify reset worked
raise "Expected 0 messages after reset, got #{exchange.published_messages.length}" unless exchange.published_messages.length == 0

# Publish a new message after reset
TestPublisher.publish({message: "Post-reset message"}.to_json, routing_key: "test")
puts "Messages after new publish: #{exchange.published_messages.length}"

# Verify only the new message is present
raise "Expected 1 message after new publish, got #{exchange.published_messages.length}" unless exchange.published_messages.length == 1

puts "✓ Mock publishing example completed successfully"
