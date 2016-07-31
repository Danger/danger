module Danger
  module RequestSources
    class RequestSource
      DANGER_REPO_NAME = 'danger'.freeze

      attr_accessor :ci_source, :environment, :scm, :host, :ignored_violations

      def self.inherited(child_class)
        available_request_sources.add child_class
        super
      end

      def self.available_request_sources
        @available_request_sources ||= Set.new
      end

      def initialize(_ci_source, _environment)
        raise 'Subclass and overwrite initialize'
      end

      # What does this do?
      def validates_as_ci?
        !!self.scm.origins.match(%r{#{Regexp.escape self.host}(:|/)(?<repo_slug>.+/.+?)(?:\.git)?$})
      end

      def scm
        @scm ||= nil
      end

      def host
        @host ||= nil
      end

      def ignored_violations
        @ignored_violations ||= []
      end

      def update_pull_request!(_warnings: [], _errors: [], _messages: [], _markdowns: [])
        raise 'Subclass and overwrite update_pull_request!'
      end

      def setup_danger_branches
        raise 'Subclass and overwrite setup_danger_branches'
      end

      def fetch_details
        raise 'Subclass and overwrite initialize'
      end

      def organisation
        raise 'Subclass and overwrite organisation'
      end

      def fetch_repository(_organisation: nil, _repository: nil)
        raise 'Subclass and overwrite fetch_repository'
      end

      def fetch_danger_repo(_organisation: nil)
        raise 'Subclass and overwrite fetch_danger_repo'
      end

      def danger_repo?(_organisation: nil, _repository: nil)
        raise 'Subclass and overwrite danger_repo?'
      end

      def file_url(_organisation: nil, _repository: nil, _branch: 'master', _path: nil)
        raise 'Subclass and overwrite file_url'
      end
    end
  end
end
