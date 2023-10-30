module Publishers ; end
module Subscribers ; end

Rails.autoloaders.main.push_dir("#{Rails.root}/app/publishers", namespace: Publishers)
Rails.autoloaders.main.push_dir("#{Rails.root}/app/subscribers", namespace: Subscribers)
