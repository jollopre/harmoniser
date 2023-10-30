module Harmoniser
  module Includable
    MUTEX = Mutex.new
    private_constant :MUTEX

    module ClassMethods
      def harmoniser_register_included(klass)
        MUTEX.synchronize do
          @harmoniser_included ||= Set.new
          @harmoniser_included << klass
        end
      end

      def harmoniser_included
        @harmoniser_included.to_a
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
