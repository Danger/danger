$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "danger"
require "webmock"
require "webmock/rspec"
require "json"

RSpec.configure do |config|
  config.filter_gems_from_backtrace "bundler"
end

WebMock.disable_net_connect!(allow: "coveralls.io")

def make_temp_file(contents)
  file = Tempfile.new("dangefile_tests")
  file.write contents
  file
end

def stub_env
  {
    "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
    "TRAVIS_PULL_REQUEST" => "800",
    "TRAVIS_REPO_SLUG" => "artsy/eigen",
    "TRAVIS_COMMIT_RANGE" => "759adcbd0d8f...13c4dc8bb61d",
    "DANGER_GITHUB_API_TOKEN" => "hi"
  }
end

def stub_ci
  env = { "CI_PULL_REQUEST" => "https://github.com/artsy/eigen/pull/800" }
  Danger::CISource::CircleCI.new(env)
end

def stub_request_source
  Danger::RequestSources::GitHub.new(stub_ci, stub_env)
end

# rubocop:disable Lint/NestedMethodDefinition
def testing_ui
  @output = StringIO.new
  def @output.winsize
    [20, 9999]
  end

  cork = Cork::Board.new(out: @output)
  def cork.string
    out.string.gsub(/\e\[([;\d]+)?m/, "")
  end
  cork
end
# rubocop:enable Lint/NestedMethodDefinition

def testing_dangerfile
  env = Danger::EnvironmentManager.new(stub_env)
  dm = Danger::Dangerfile.new(env, testing_ui)
end

def fixture(file)
  File.read("spec/fixtures/#{file}.json")
end

def comment_fixture(file)
  File.read("spec/fixtures/#{file}.html")
end

def diff_fixture(file)
  File.read("spec/fixtures/#{file}.diff")
end

def violation(message, sticky: false)
  Danger::Violation.new(message, sticky, nil, nil)
end

def violations(messages, sticky: false)
  messages.map { |s| violation(s, sticky: sticky) }
end

def markdown(message)
  Danger::Markdown.new(message, nil, nil)
end

def markdowns(messages)
  messages.map { |s| markdown(s) }
end
