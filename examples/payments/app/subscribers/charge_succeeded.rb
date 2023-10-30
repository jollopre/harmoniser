module Subscribers
  class ChargeSucceeded
    USE_CASE = "succeeded_use_case"
    SERVICE_NAME = "payments"
    QUEUE_NAME = "production/qu/#{SERVICE_NAME}/#{USE_CASE}/#{Publishers::ChargesPublisher::OWNER}"

    include Harmoniser::Subscriber
    harmoniser_subscriber queue_name: QUEUE_NAME

    class << self
      def on_delivery(delivery_info, properties, payload)
        payload = {
          body: "message received",
          payload: payload
        }
        Harmoniser.logger.info(payload.to_json)
      end
    end
  end
end
