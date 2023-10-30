module Harmoniser
  Options = Data.define(:environment, :require, :verbose) do
    def production?
      environment == "production"
    end

    def verbose?
      !!verbose
    end
  end
end
