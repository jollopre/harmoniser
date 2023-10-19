module Harmoniser
  module Definition
    Binding = Data.define(:exchange_name, :destination_name, :destination_type, :opts) do
      def queue?
        [:queue, "queue"].include?(destination_type)
      end

      def exchange?
        [:exchange, "exchange"].include?(destination_type)
      end
    end

    Consumer = Data.define(:queue_name, :consumer_tag, :no_ack, :exclusive, :arguments)

    Exchange = Data.define(:name, :type, :opts) do
      def hash
        [self.class, name].hash
      end

      def eql?(other)
        self.class == other.class && name == other.name
      end
    end

    Queue = Data.define(:name, :opts) do
      def hash
        [self.class, name].hash
      end

      def eql?(other)
        self.class == other.class && name == other.name
      end
    end
  end
end
