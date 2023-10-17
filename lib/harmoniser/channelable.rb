module Harmoniser
  module Channelable
    MUTEX = Mutex.new
    private_constant :MUTEX

    module ClassMethods
      def harmoniser_channel
        MUTEX.synchronize do
          @harmoniser_channel ||= create_channel
        end
      end

      def create_channel
        connection = Harmoniser.connection
        connection.create_channel
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
