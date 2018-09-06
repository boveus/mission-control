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

    def commit
      @payload['pull_request']['head']['sha']
    end

    def base_branch
      @payload['pull_request']['base']['ref']
    end

    # Functionality
    def approvals
      return @approvals unless @approvals.nil?

      pr_reviews = github.pull_request_reviews(repo, pr_number, :accept => 'application/vnd.github.v3+json')

      last_reviews = {}
      pr_reviews.reject! { |review| review[:state] == 'COMMENTED' }
      pr_reviews.each { |review| last_reviews[review[:user][:login]] = review[:state] }

      @approvals = (last_reviews.select { |_key, value| value == 'APPROVED' }).keys
    end

    def files
      @files ||= github.pull_files(repo, pr_number).map { |file| "/#{file[:filename]}" }
    end

    def status(state:, name:, description:)
      github.create_status(repo, commit, state,
                           context: "mission-control/#{name.parameterize}",
                           description: description)
    end

    private

    def github
      MissionControl::Services::GithubService.client
    end
  end
end
