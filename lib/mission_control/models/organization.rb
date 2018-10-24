module MissionControl::Models
  class Organization
    attr_accessor :organization

    def initialize(organization:)
      @organization = organization
    end

    def teams
      @teams ||= github.org_teams(organization).map do |team|
        MissionControl::Models::Team.new(team: team)
      end
    end

    private

    def github
      MissionControl::Services::GithubService.client
    end
  end
end
