module MissionControl::Models
  class PullRequest
    attr_accessor :event_type

    def initialize(event_type:, payload:)
      @event_type = event_type
      @payload = payload
    end

    # Getters
    def repo
      @payload['repository']['full_name']
    end

    def pr_number
      @payload['pull_request']['number']
    end

    def last_commit_sha
      @payload['pull_request']['head']['sha']
    end

    def last_commit
      @last_commit ||= github.commit(repo, last_commit_sha, :accept => 'application/vnd.github.v3+json')
    end

    def commits
      @commits ||= github.pull_request_commits(repo, pr_number, :accept => 'application/vnd.github.v3+json')
    end

    def base_branch
      @payload['pull_request']['base']['ref']
    end

    def last_base_branch_commit
      @last_base_branch_commit ||= github.commit(repo, base_branch, :accept => 'application/vnd.github.v3+json')
    end

    def reviews
      @reviews ||= github.pull_request_reviews(repo, pr_number, :accept => 'application/vnd.github.v3+json')
    end

    # Functionality
    def update_with_master?
      return false unless @payload['action'] == 'synchronize'

      parent_commit_shas = last_commit[:parents].map { |parent| parent[:sha] }

      return false unless parent_commit_shas.count == 2
      return false unless parent_commit_shas.include?(last_base_branch_commit[:sha])
      true
    end

    def approved_reviews
      reviews
        .reject { |review| review[:state] == 'COMMENTED' }
        .reverse.uniq { |review| review[:user][:login] }.reverse
        .select { |review| review[:state] == 'APPROVED' }
    end

    def approvals
      approved_reviews.map { |review| review[:user][:login] }
    end

    def files
      @files ||= github.pull_files(repo, pr_number).map { |file| "/#{file[:filename]}" }
    end

    def new_commits
      return commits if reviews.empty?

      index = commits.find_index do |commit|
        commit[:sha] == reviews.last[:commit_id]
      end

      index.nil? ? commits : commits[index + 1..-1]
    end

    def commits_with_changes
      new_commits.reject do |commit|
        parent_shas = commit[:parents].map { |parent| parent[:sha] }

        next false if parent_shas.count == 1

        parent_shas.any? do |sha|
          ['behind', 'identical'].include?(github.compare(repo, base_branch, sha)['status'])
        end
      end
    end

    def changed_files
      return @changed_files unless @changed_files.nil?
      commits_with_changes.map do |commit|
        github.commit(repo, commit[:sha])[:files].map { |file| "/#{file[:filename]}" }
      end.flatten.uniq
    end

    def status(state:, name:, description:)
      github.create_status(repo, last_commit_sha, state,
                           context: "mission-control/#{name.parameterize}",
                           description: description)
    end

    def dismiss(reviews)
      reviews.each do |review|
        github.dismiss_pull_request_review(repo, pr_number, review[:id], 'Dismissed by Mission Control')
      end

      @reviews = nil
    end

    private

    def github
      MissionControl::Services::GithubService.client
    end
  end
end
