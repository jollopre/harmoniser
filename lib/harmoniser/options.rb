module Harmoniser
  Options = Data.define(:concurrency, :environment, :require, :verbose, :timeout) do
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
