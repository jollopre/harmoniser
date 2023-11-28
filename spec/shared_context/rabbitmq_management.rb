require "net/http"
require "json"

RSpec.shared_context "rabbitMQ management" do
  let(:host) { ENV.fetch("RABBITMQ_HOST") }
  let(:url) do
    "http://#{host}:15672/api/definitions"
  end

  def get_definitions
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request.basic_auth("guest", "guest")
    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    return JSON.parse(response.body, symbolize_names: true) if response.code == "200"

    {}
  end
end
