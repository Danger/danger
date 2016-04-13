# For more info see: https://github.com/schacon/ruby-git

require 'git'

module Danger
  class GitRepo
    attr_accessor :diff

    def diff_for_folder(folder, from: "master", to: 'HEAD')
      repo = Git.open folder
      self.diff = repo.diff(from, to)
    end

    def exec(string)
      `git #{string}`.strip
    end

    def added_files
      Danger::FileList.new(@diff.select { |diff| diff.type == "new" }.map(&:path))
    end

    def deleted_files
      Danger::FileList.new(@diff.select { |diff| diff.type == "deleted" }.map(&:path))
    end

    def modified_files
      files = @diff.stats[:files].keys.map(&method(:extract_new_file))
      Danger::FileList.new(files)
    end

    def lines_of_code
      @diff.lines
    end

    def deletions
      @diff.deletions
    end

    def insertions
      @diff.insertions
    end

    private

    def extract_new_file(git_file)
      git_file.gsub(/{?(.*) => (.*)}?/, "\\2")
    end
  end
end
