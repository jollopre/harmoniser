RSpec.shared_context "configurable" do
  let(:bunny) { Bunny.new(host: "rabbitmq").start }

  before do
    Harmoniser.configure do |config|
      config.connection_opts = {
        host: "rabbitmq",
      }
      config.options_with(environment: "test")
    end
  end
end
