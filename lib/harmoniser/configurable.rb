require "harmoniser/configuration"

module Harmoniser
  module Configurable
    def configure
      @configuration ||= Configuration.new
      yield(@configuration)
    end

    def configuration
      raise NoMethodError.new("Please, configure first") unless @configuration

      @configuration
    end

    def default_configuration
      @configuration ||= Configuration.new
    end
  end
end
