module Publishers
  class ChargesPublisher
    OWNER = "com.myorg.payments"
    EXCHANGE_NAME = "production/ex/#{OWNER}/main"

    include Harmoniser::Publisher
    harmoniser_publisher exchange_name: EXCHANGE_NAME

    class << self
      def succeeded(data = {})
        publish(
          data.to_json,
          routing_key: "#{OWNER}.1-0.event.charge.succeeded"
        )
      end
    end
  end
end
