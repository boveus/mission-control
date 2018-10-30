module MissionControl::Models
  class Control
    def self.fetch(pull_request:)
      github = MissionControl::Services::GithubService.client
      response = github.content(
        pull_request.repo,
        :path => MissionControl::CONFIG_FILE,
        :ref => pull_request.base_branch
      )

      return if response.nil? || response[:content].nil?
      controls = YAML.safe_load(Base64.decode64(response[:content]))

      controls.map do |control|
        control = control.values.first
        Control.new(
          pull_request: pull_request,
          name: control['name'],
          users: control['users'],
          teams: control['teams'],
          paths: control['paths'],
          count: control['count'],
          dismissal_paths: control['dismissal_paths'],
          dismiss_enabled: control['dismiss']
        )
      end
    end

    def self.execute!(pull_request:)
      controls = Control.fetch(pull_request: pull_request)
      return unless controls
      return if pull_request.update_with_master?

      control_description = "repo: #{pull_request.repo} base_branch: #{pull_request.base_branch}"
      puts "Executing #{controls.length} Controls | #{control_description} | PR: #{pull_request.pr_number}"
      controls.each(&:dismiss_reviews!)
      controls.each(&:execute!)
    end

    attr_accessor :pull_request, :name, :users, :teams, :paths, :count, :dismissal_paths, :dismiss_enabled

    def initialize(pull_request:, **controls)
      @pull_request = pull_request
      @name = controls[:name]
      @users = controls[:users]
      @teams = controls[:teams] || []
      @paths = controls[:paths] || '*'
      @count = controls[:count] || 1
      @dismissal_paths = controls[:dismissal_paths] || @paths
      @dismiss_enabled = controls[:dismiss_enabled].nil? || controls[:dismiss_enabled]
    end

    def authorized_users
      @users | team_members
    end

    def active?
      PathSpec.from_lines(@paths).match_paths(pull_request.files).any?
    end

    def execute!
      active? ? execute_active! : execute_inactive!
    end

    def dismissable?
      return false unless dismiss_enabled
      PathSpec.from_lines(@dismissal_paths).match_paths(pull_request.changed_files).any?
    end

    def dismiss_reviews!
      execute_dismissals! if dismissable?
    end

    def team_members
      return [] if teams.empty?

      authorized_teams = pull_request.organization.teams.select do |github_team|
        teams.include?(github_team.slug)
      end
      authorized_teams.map(&:members).flatten.map { |member| member[:login] }.uniq
    end

    private

    def execute_active!
      approvals = (pull_request.approvals & authorized_users)

      state = approvals.length < count ? 'pending' : 'success'
      description = "Required: #{count}"
      description += " | Approved by: #{approvals.join(', ')}" unless approvals.empty?

      pull_request.status(state: state, name: name, description: description)
    end

    def execute_inactive!
      pull_request.status(state: 'success', name: name, description: 'Not Required')
    end

    def execute_dismissals!
      dismissals = pull_request.approved_reviews.select do |review|
        authorized_users.include? review[:user][:login]
      end

      pull_request.dismiss(dismissals) unless dismissals.empty?
    end
  end
end
