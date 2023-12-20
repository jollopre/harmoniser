require "logger"
require "harmoniser/version"

module Harmoniser
  module Loggable
    def logger
      @logger ||= Logger.new($stdout, progname: "harmoniser@#{VERSION}")
    end
  end
end
