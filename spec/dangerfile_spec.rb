require 'pathname'
require 'tempfile'

describe Danger::Dangerfile do
  it 'keeps track of the original Dangerfile' do
    file = make_temp_file ""
    dm = Danger::Dangerfile.new
    dm.parse file.path
    expect(dm.defined_in_file).to eq file.path
  end

  it 'runs the ruby code inside the Dangerfile' do
    code = "message('hi')"
    expect_any_instance_of(Danger::Dangerfile).to receive(:puts).and_return("")
    dm = Danger::Dangerfile.new
    dm.parse Pathname.new(""), code
  end

  it 'raises elegantly with bad ruby code inside the Dangerfile' do
    code = "asdas = asdasd + asdasddas"
    dm = Danger::Dangerfile.new

    expect do
      dm.parse Pathname.new(""), code
    end.to raise_error(Danger::DSLError)
  end

  it 'respects ignored violations' do
    code = "message 'A message'\n" \
           "warn 'An ignored warning'\n" \
           "warn 'A warning'\n" \
           "fail 'An ignored error'\n" \
           "fail 'An error'\n"

    dm = Danger::Dangerfile.new
    env = {
      "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
      "TRAVIS_PULL_REQUEST" => "800",
      "TRAVIS_REPO_SLUG" => "artsy/eigen",
      "TRAVIS_COMMIT_RANGE" => "759adcbd0d8f...13c4dc8bb61d"
    }
    dm.env = Danger::EnvironmentManager.new(env)
    dm.env.scm = Danger::GitRepo.new
    dm.env.request_source.ignored_violations = ['A message', 'An ignored warning', 'An ignored error']

    dm.parse Pathname.new(""), code

    expect(dm.messages.map(&:message)).to eql(['A message'])
    expect(dm.warnings.map(&:message)).to eql(['A warning'])
    expect(dm.errors.map(&:message)).to eql(['An error'])
  end

  describe "#print_results" do
    it "Prints out 3 tables" do
      code = "message 'A message'\n" \
             "warn 'Another warning'\n" \
             "warn 'A warning'\n" \
             "fail 'Another error'\n" \
             "fail 'An error'\n"
      dm = Danger::Dangerfile.new
      env = {
        "HAS_JOSH_K_SEAL_OF_APPROVAL" => "true",
        "TRAVIS_PULL_REQUEST" => "800",
        "TRAVIS_REPO_SLUG" => "artsy/eigen",
        "TRAVIS_COMMIT_RANGE" => "759adcbd0d8f...13c4dc8bb61d"
      }
      dm.env = Danger::EnvironmentManager.new(env)
      dm.env.scm = Danger::GitRepo.new
      dm.env.request_source.ignored_violations = ['A message', 'An ignored warning', 'An ignored error']

      dm.parse Pathname.new(""), code

      expect(Terminal::Table).to receive(:new).with({
        rows: [["Another error"], ["An error"]],
        title: "Errors".red
      })
      expect(Terminal::Table).to receive(:new).with({
        rows: [["Another warning"], ["A warning"]],
        title: "Warnings".yellow
      })
      expect(Terminal::Table).to receive(:new).with({
        rows: [["A message"]],
        title: "Messages"
      })
      dm.print_results
    end
  end

  describe "verbose" do
    it 'outputs metadata when verbose' do
      file = make_temp_file ""
      dm = Danger::Dangerfile.new
      dm.verbose = true

      expect(dm).to receive(:print_known_info)
      dm.parse file.path
    end
    it 'does not print metadata by default' do
      file = make_temp_file ""
      dm = Danger::Dangerfile.new

      expect(dm).to_not receive(:print_known_info)
      dm.parse file.path
    end
  end
end
