# For more info see: https://github.com/schacon/ruby-git

require 'git'
require 'uri'

module Danger
  module CISource
    class LocalGitRepo < CI
      attr_accessor :base_commit, :head_commit

      def self.validates?(env)
        return !env["DANGER_USE_LOCAL_GIT"].nil?
      end

      def git
        @git ||= GitRepo.new
      end

      def run_git(command)
        git.exec command
      end

      def initialize(env = {})
        github_host = env["DANGER_GITHUB_HOST"] || "github.com"

        # get the remote URL
        remote = run_git "remote show origin -n | grep \"Fetch URL\" | cut -d ':' -f 2-"
        if remote
          remote_url_matches = remote.match(%r{#{Regexp.escape github_host}(:|/)(?<repo_slug>.+/.+?)(?:\.git)?$})
          if !remote_url_matches.nil? and remote_url_matches["repo_slug"]
            self.repo_slug = remote_url_matches["repo_slug"]
          else
            puts "Danger local requires a repository hosted on GitHub.com or GitHub Enterprise."
          end
        end

        # get the most recent PR merge
        pr_merge = run_git "log --since='2 weeks ago' --merges --oneline | grep \"Merge pull request\" | head -n 1".strip
        if pr_merge.to_s.empty?
          raise "No recent pull requests found for this repo, danger requires at least one PR for the local mode"
        end

        self.pull_request_id = pr_merge.match("#([0-9]+)")[1]
        sha = pr_merge.split(" ")[0]
        parents = run_git("rev-list --parents -n 1 #{sha}").strip.split(" ")
        self.base_commit = parents[0]
        self.head_commit = parents[1]
      end
    end
  end
end
