module Danger
  class Runner < CLAide::Command
    require "danger/commands/init"
    require "danger/commands/local"
    require "danger/commands/systems"

    # manually set claide plugins as a subcommand
    require "claide_plugin"
    @subcommands << CLAide::Command::Plugins
    CLAide::Plugins.config =
      CLAide::Plugins::Configuration.new("Danger",
                                         "danger",
                                         "https://raw.githubusercontent.com/danger/danger.systems/master/plugins-search-generated.json",
                                         "https://github.com/danger/danger-plugin-template")

    require "danger/commands/plugins/plugin_lint"
    require "danger/commands/plugins/plugin_json"
    require "danger/commands/plugins/plugin_readme"

    attr_accessor :cork

    self.summary = "Run the Dangerfile."
    self.command = "danger"
    self.version = Danger::VERSION

    self.plugin_prefixes = %w(claide danger)

    def initialize(argv)
      dangerfile = argv.option("dangerfile", self.class.path_for_implicit_dangerfile)
      @dangerfile_path = dangerfile if File.exist? dangerfile
      @base = argv.option("base")
      @head = argv.option("head")
      @danger_id = argv.option("danger_id", "danger")
      @cork = Cork::Board.new(silent: argv.option("silent", false),
                              verbose: argv.option("verbose", false))
      super
    end

    def validate!
      super
      if self.class == Runner && !@dangerfile_path
        help! "Could not find a Dangerfile."
      end
    end

    # Determines the Dangerfile based on the current folder structure
    def self.path_for_implicit_dangerfile
      ["Dangerfile", "Dangerfile.rb", "Dangerfile.js"].each do |file|
        return file if File.exist? file
      end
      abort("Could not find a Dangerfile to run.".red)
    end

    def self.options
      [
        ["--base=[master|dev|stable]", "A branch/tag/commit to use as the base of the diff"],
        ["--head=[master|dev|stable]", "A branch/tag/commit to use as the head"],
        ["--dangerfile=<path/to/dangerfile>", "The location of your Dangerfile"],
        ["--danger_id=<id>", "The identifier of this Danger instance"]
      ].concat(super)
    end

    def run
      Executor.new.run(base: @base,
                       head: @head,
                       dangerfile_path: @dangerfile_path,
                       danger_id: @danger_id,
                       verbose: @verbose)
    end
  end
end
