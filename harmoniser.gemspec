# frozen_string_literal: true

require_relative "lib/harmoniser/version"

Gem::Specification.new do |spec|
  spec.name = "harmoniser"
  spec.version = Harmoniser::VERSION
  spec.authors = ["Jose Lloret"]
  spec.email = ["jollopre@gmail.com"]

  spec.summary = "A data sync library for independent services"
  spec.description = "Harmoniser makes it easy to synchronise data across services"
  spec.homepage = "https://github.com/jollopre/harmoniser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.4.0"

  spec.metadata["allowed_push_host"] = ""

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jollopre/harmoniser"
  spec.metadata["changelog_uri"] = "https://github.com/jollopre/harmoniser/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files = Dir.chdir(File.expand_path(__dir__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  # end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "bunny", "~> 2.22"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "standardrb", "~> 1.0"
end
