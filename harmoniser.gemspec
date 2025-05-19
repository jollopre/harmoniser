# frozen_string_literal: true

require_relative "lib/harmoniser/version"

Gem::Specification.new do |spec|
  spec.name = "harmoniser"
  spec.version = Harmoniser::VERSION
  spec.authors = ["Jose Lloret"]
  spec.email = ["jollopre@gmail.com"]

  spec.summary = "A minimalistic approach to interact with RabbitMQ"
  spec.description = "A declarative approach to communication with RabbitMQ that simplifies the integration of publishing and consuming messages."
  spec.homepage = "https://github.com/jollopre/harmoniser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/jollopre/harmoniser",
    "changelog_uri" => "https://github.com/jollopre/harmoniser/blob/master/CHANGELOG.md"
  }

  spec.files = Dir["lib/**/*.rb"] + Dir["bin/*"] + Dir["docs/**/*", "CHANGELOG.md", "CODE_OF_CONDUCT.md", "harmoniser.gemspec", "LICENSE.txt", "README.md"]
  spec.executables = ["harmoniser"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "bunny", "~> 2.24"
end
