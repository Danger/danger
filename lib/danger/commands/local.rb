module Danger
  class Local < Runner
    self.summary = 'Run the Dangerfile locally.'
    self.command = 'local'

    def initialize(argv)
      @dangerfile_path = "Dangerfile" if File.exist? "Dangerfile"
      @pr_num = argv.option('use-merged-pr')
      super
    end

    def self.options
      [
        ['--use-merged-pr=[#id]', 'The ID of an alreadty merged PR inside your history to use as a reference for the local run.']
      ].concat(super)
    end

    def validate!
      super
      unless @dangerfile_path
        help! "Could not find a Dangerfile."
      end
    end

    def run
      ENV["DANGER_USE_LOCAL_GIT"] = "YES"
      ENV["LOCAL_GIT_PR_ID"] = @pr_num if @pr_num

      dm = Dangerfile.new
      dm.env = EnvironmentManager.new(ENV)

      source = dm.env.ci_source
      if source.nil? or source.repo_slug.empty?
        puts "danger local failed because it only works with GitHub projects at the moment. Sorry.".red
        exit 0
      end

      gh = dm.env.request_source

      puts "Running your Dangerfile against this PR - https://#{gh.github_host}/#{source.repo_slug}/pull/#{source.pull_request_id}"

      if verbose != true
        puts "Turning on --verbose"
        dm.verbose = true
      end

      puts ""

      # We can use tokenless here, as it's running on someone's computer
      # and is IP locked, as opposed  to on the CI.
      gh.support_tokenless_auth = true
      gh.fetch_details

      dm.env.request_source = gh

      dm.env.scm = GitRepo.new

      dm.env.ensure_danger_branches_are_setup
      dm.env.scm.diff_for_folder(".", from: dm.env.ci_source.base_commit, to: dm.env.ci_source.head_commit)
      dm.parse(Pathname.new(@dangerfile_path))
      dm.print_results
    end
  end
end
