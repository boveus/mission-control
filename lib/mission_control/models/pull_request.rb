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

    def last_commit
      @payload['pull_request']['head']['sha']
    end

    def commits
      @commits ||= github.pull_request_commits(repo, pr_number, :accept => 'application/vnd.github.v3+json')
    end

    def base_branch
      @payload['pull_request']['base']['ref']
    end

    def reviews
      @reviews ||= github.pull_request_reviews(repo, pr_number, :accept => 'application/vnd.github.v3+json')
    end

    # Functionality
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
      return @new_commits unless @new_commits.nil?

      @new_commits =
        if reviews.empty?
          commits
        else
          commits.reject do |commit|
            commit[:commit][:committer][:date] < reviews.last[:submitted_at]
          end
        end
    end

    def changed_files
      return @changed_files unless @changed_files.nil?

      new_commits.map do |commit|
        github.commit(repo, commit[:sha])[:files].map { |file| "/#{file[:filename]}" }
      end.flatten.uniq
    end

    def status(state:, name:, description:)
      github.create_status(repo, last_commit, state,
                           context: "mission-control/#{name.parameterize}",
                           description: description)
    end

    def dismiss(reviews)
      reviews.each do |review|
        github.dismiss_pull_request_review(repo, pr_number, review[:id], 'Dismissed by Mission Control')
      end

      @reviews = github.pull_request_reviews(repo, pr_number, :accept => 'application/vnd.github.v3+json')
    end

    private

    def github
      MissionControl::Services::GithubService.client
    end
  end
end
