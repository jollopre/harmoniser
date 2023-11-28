RSpec.shared_context "configurable" do
  let(:host) { ENV.fetch("RABBITMQ_HOST") }
  let(:bunny) { Bunny.new(host: host).start }

  before do
    Harmoniser.configure do |config|
      config.connection_opts = {host: host}
      config.options_with(environment: "test")
    end
  end
end
