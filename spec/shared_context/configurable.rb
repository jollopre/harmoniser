RSpec.shared_context "configurable" do
  before(:each) do
    Harmoniser.configure do |config|
      config.bunny = {host: "rabbitmq"}
    end
  end
end
