RSpec.shared_context "configurable" do
  before(:each) do
    Harmoniser.configure do |config|
      config.bunny = {host: "rabbitmq"}
    end
  end
  let(:bunny) { Harmoniser.bunny }
end
