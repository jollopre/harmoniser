module Harmoniser
  class Launcher
    def initialize(configuration:, logger:)
      @configuration = configuration
      @logger = logger
    end

    def start
      boot_app
      start_subscribers
    end

    private

    def boot_app
      if File.directory?(@configuration.require)
        load_rails
      else
        load_file
      end
    end

    # TODO - Frameworks like Rails which have autoload for development/test will not start any subscriber unless the files where subscribers are located are required explicitly. Since we premier production and the eager load ensures that every file is loaded, this approach works
    def start_subscribers
      klasses = Subscriber.harmoniser_included
      klasses.each do |klass|
        klass.harmoniser_subscriber_start
      end
      @logger.info("Subscribers registered to consume messages from queues: klasses = `#{klasses}`")
    end

    private

    def load_rails
      filepath = File.expand_path("#{@configuration.require}/config/environment.rb")
      require filepath
    rescue LoadError => e
      @logger.warn("Error while requiring file within directory. No subscribers will run for this process: require = `#{@configuration.require}`, filepath = `#{filepath}`, error_class = `#{e.class}`, error_message = `#{e.message}`, error_backtrace = `#{e.backtrace&.first(5)}`")
    end

    def load_file
      require @configuration.require
    rescue LoadError => e
      @logger.warn("Error while requiring file. No subscribers will run for this process: require = `#{@configuration.require}`, error_class = `#{e.class}`, error_message = `#{e.message}`, error_backtrace = `#{e.backtrace&.first(5)}`")
    end
  end
end
