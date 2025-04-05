# Publisher

The Publisher module provides a way to publish messages to a RabbitMQ exchange. It is designed to be included in a class that needs to publish messages. It requires the class to define an exchange using the **harmoniser_publisher** method.

## Example

```
class MyPublisher
  include Harmoniser::Publisher
  # Define the exchange to publish to
  harmoniser_publisher exchange_name: "exchange_name"
end

# Publish a message to the exchange defined in the class
MyPublisher.publish({foo: "bar"}, routing_key: "foo")
```

