module Geordi
  class Git
    class << self
      def local_branch_names
        @local_branch_names ||= begin
          branch_list_string = if Util.testing?
            ENV['GEORDI_TESTING_GIT_BRANCHES'].to_s
          else
            `git branch --format="%(refname:short)"`
          end

          branch_list_string.strip.split("\n")
        end
      end

      def current_branch
        if Util.testing?
          git_default_branch
        else
          `git rev-parse --abbrev-ref HEAD`.strip
        end
      end

      def staged_changes?
        if Util.testing?
          ENV['GEORDI_TESTING_STAGED_CHANGES'] == 'true'
        else
          statuses = `git status --porcelain`.split("\n")
          statuses.any? { |l| /^[A-Z]/i =~ l }
        end
      end

      def git_default_branch
        default_branch = if Util.testing?
          ENV['GEORDI_TESTING_DEFAULT_BRANCH']
        else
          head_symref = `git ls-remote --symref origin HEAD`
          head_symref[%r{\Aref: refs/heads/(\S+)\sHEAD}, 1]
        end

        default_branch || 'master'
      end

      def extract_linear_issue_id(target_branch, source_branch)
        commits = if Util.testing?
          ENV['GEORDI_TESTING_GIT_COMMITS']
        else
          `git --no-pager log --pretty=format:%s origin/#{target_branch}..#{source_branch}`
        end

        commits = commits.split("\n")
        found_ids = []

        regex = /^\[[A-Z]+-\d+\]/

        commits.each do |line|
          line.scan(regex) do |match|
            found_ids << match
          end
        end

        found_ids.map { |id| id.delete('[]') } # [W-365] => W-365
      end
    end
  end
end
