module Harmoniser
  class Options < Data.define(:concurrency, :environment, :require, :verbose, :timeout)
    DEFAULT = {
      concurrency: -> { Float::INFINITY },
      environment: -> { ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "production")) },
      require: -> { "." },
      timeout: -> { 25 },
      verbose: -> { false }
    }.freeze

    def initialize(**kwargs)
      options = DEFAULT
        .map { |k, v| [k, v.call] }
        .to_h
        .merge(kwargs)
      super(**options)
    end

    def production?
      environment == "production"
    end

    def unbounded_concurrency?
      concurrency == Float::INFINITY
    end

    def verbose?
      !!verbose
    end
  end
end
