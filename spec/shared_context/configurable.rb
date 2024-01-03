RSpec.shared_context "configurable" do
  let(:host) { ENV.fetch("RABBITMQ_HOST") }
  let(:bunny) { Bunny.new(host: host, logger: Logger.new(IO::NULL)).start }

  before do
    Harmoniser.configure do |config|
      config.connection_opts = {host: host}
      config.options_with(environment: "test")
    end
  end

  def declare_exchange(name)
    channel = bunny.create_channel
    Bunny::Exchange.new(channel, :direct, name, {auto_delete: true})
  end

  def declare_queue(name, exchange_name)
    channel = bunny.create_channel
    Bunny::Queue.new(channel, name, {auto_delete: true}).bind(exchange_name)
  end
end
