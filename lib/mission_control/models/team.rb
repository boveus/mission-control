module MissionControl::Models
  class Team
    attr_accessor :team

    def initialize(team:)
      @team = team
    end

    def id
      team[:id]
    end

    def slug
      team[:slug]
    end

    def members
      @members ||= github.team_members(id, :accept => 'application/vnd.github.v3+json')
    end

    private

    def github
      MissionControl::Services::GithubService.client
    end
  end
end
