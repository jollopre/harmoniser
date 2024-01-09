module Harmoniser
  module Subscriber
    class RetrierProperties

      attr_reader :error, :message_properties, :retrier, :retry_count

      def initialize(error, message_properties, retrier)
        @error = error
        @message_properties = message_properties
        @retrier = retrier
      end

      def next?
        retry_count < max_retries
      end

      def next
        expiration = exponential_backoff(1000, retry_count)

        message_properties.to_hash.merge(
          routing_key: retrier.awaiting_queue_name,
          expiration: expiration,
          headers: headers.merge(
            "harmoniser_retry_count" => retry_count,
            "harmoniser_max_retries" =>  max_retries,
            "harmoniser_error_class" => error.class.to_s,
            "harmoniser_error_message" => error.message,
            "harmoniser_failed_at" => nil
          )
        )
      end

      def retry_count
        headers.fetch("harmoniser_retry_count", -1) + 1
      end

      def max_retries
        headers.fetch("harmoniser_max_retries", retrier.max_retries)
      end

      private

      def headers
        message_properties.headers || {}
      end

      def exponential_backoff(base_delay, attempt_number)
        base_delay * 2**attempt_number
      end
    end
  end
end
