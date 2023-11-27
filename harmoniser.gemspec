# frozen_string_literal: true

require_relative "lib/harmoniser/version"

Gem::Specification.new do |spec|
  spec.name = "harmoniser"
  spec.version = Harmoniser::VERSION
  spec.authors = ["Jose Lloret"]
  spec.email = ["jollopre@gmail.com"]

  spec.summary = "A minimalistic approach to communicate with RabbitMQ"
  spec.description = "A declarative approach to communicate with RabbitMQ, that uses the reference low level library, to integrate publishing and consuming of messages"
  spec.homepage = "https://github.com/jollopre/harmoniser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/jollopre/harmoniser",
    "changelog_uri" => "https://github.com/jollopre/harmoniser/blob/master/CHANGELOG.md"
  }

  spec.files = Dir["lib/**/*.rb"] + Dir["bin/*"] + Dir["docs/**/*", "CHANGELOG.md", "CODE_OF_CONDUCT.md", "harmoniser.gemspec", "LICENSE.txt", "README.md"]
  spec.executables = ["harmoniser"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "bunny", "~> 2.22"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standardrb", "~> 1.0"
end
