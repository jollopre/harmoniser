require "bundler/setup"
require "harmoniser"

Harmoniser.configure do |config|
  config.bunny = {host: "rabbitmq"}
end

class Publisher
  include Harmoniser::Publisher

  harmoniser_publisher name: "", type: :direct do |exchange|
    exchange.on_return do |basic_return, properties, payload|
      puts "#{payload} was returned! reply_code = #{basic_return.reply_code}, reply_text = #{basic_return.reply_text}"
    end
  end
end

Publisher
  .publish("Hello World!", mandatory: true)
  .publish("Another Hello World!", mandatory: true)

sleep(5)
