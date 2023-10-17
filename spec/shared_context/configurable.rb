RSpec.shared_context "configurable" do
  before(:each) do
    Harmoniser.configure do |config|
      config.connection_opts = {
        host: "rabbitmq"
      }
    end
  end
  let(:bunny) { Bunny.new(host: "rabbitmq").start }
end
