# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "danger/version"

Gem::Specification.new do |spec|
  spec.name          = "danger"
  spec.version       = Danger::VERSION
  spec.authors       = ["Orta Therox", "Felix Krause"]
  spec.email         = ["orta.therox@gmail.com", "danger@krausefx.com"]
  spec.license       = "MIT"

  spec.summary       = Danger::DESCRIPTION
  spec.description   = "Stop Saying 'You Forgot To…' in Code Review"
  spec.homepage      = "http://github.com/danger/danger"

  spec.files         = Dir["lib/**/*"] + %w(bin/danger README.md LICENSE)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.0.0"

  # So we can have plugins, and commands
  spec.add_runtime_dependency "claide", "~> 1.0"
  spec.add_runtime_dependency "claide-plugins", "> 0.9.0"

  # Colour is important in command line tools
  spec.add_runtime_dependency "colored", "~> 1.2"

  # To provide git metadata
  spec.add_runtime_dependency "git", "~> 1"

  # So we can talk to GitHub
  spec.add_runtime_dependency "octokit", "~> 4.2"

  # This is a transitive of octokit, but making it explicit
  # as we use it as our HTTP client
  spec.add_runtime_dependency "faraday", "~> 0.9"
  spec.add_runtime_dependency "faraday-http-cache", "~> 1.0"

  # Markdown rendering
  spec.add_runtime_dependency "kramdown", "~> 1.5"

  # For showing tables of information
  spec.add_runtime_dependency "terminal-table", "~> 1"

  # UI wrapper
  spec.add_runtime_dependency "cork", "~> 0.1"
  spec.add_runtime_dependency "gitlab", "~> 3.7.0"

  # JS support, tests would not run otherwise.
  # However, therubyracer does not work on windows, so we have
  # tests for failing the build in that context.
  spec.add_development_dependency("danger-js", "~> 1.0") unless Gem.win_platform?

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.4"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.2"
  spec.add_development_dependency "webmock", "~> 2.1"
  spec.add_development_dependency "pry", "~> 0.10"

  spec.add_development_dependency "rubocop", "~> 0.38"
  spec.add_development_dependency "yard", "~> 0.8"

  # I'm super fancy with testing, all the bells and whistles
  # use `bundle exec guard` to autolisten for tests
  spec.add_development_dependency "listen", "3.0.7"
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"
  spec.add_development_dependency "guard-rubocop", "~> 1.2"
  spec.add_development_dependency "terminal-notifier", "~> 1.6"
  spec.add_development_dependency "terminal-notifier-guard", "~> 1.6"
  spec.add_development_dependency "simplecov", "~> 0.12.0"
end
