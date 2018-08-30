module MissionControl::Models
  class Control
    def self.fetch(pull_request:)
      github = MissionControl::Services::GithubService.client
      response = github.content(
        pull_request.repo,
        :path => MissionControl::CONFIG_FILE,
        :ref => pull_request.base_branch
      )

      return if response.nil? && response[:content].nil?
      controls = YAML.safe_load(Base64.decode64(response[:content]))

      controls.map do |control|
        control = control.values.first
        Control.new(
          pull_request: pull_request,
          name: control['name'],
          users: control['users'],
          paths: control['paths'],
          count: control['count']
        )
      end
    end

    def self.execute!(pull_request:)
      controls = Control.fetch(pull_request: pull_request)

      puts "Executing #{controls.length} Controls for #{pull_request.repo} on Pull Request: #{pull_request.pr_number}"
      controls.each(&:execute!)
    end

    attr_accessor :pull_request, :name, :users, :paths, :count

    def initialize(pull_request:, name:, users:, paths: '*', count: 1)
      @pull_request = pull_request
      @name = name
      @users = users
      @paths = paths || '*'
      @count = count || 1
    end

    def active?
      !PathSpec.from_lines(@paths).match_paths(pull_request.files).empty?
    end

    def execute!
      active? ? execute_active! : execute_inactive!
    end

    private

    def execute_active!
      approvals = (pull_request.approvals & users)

      state = approvals.length < count ? 'pending' : 'success'
      description = "#{approvals.length} of #{count}"
      description += " (#{approvals.join(', ')})" unless approvals.empty?

      pull_request.status(state: state, name: name, description: description)
    end

    def execute_inactive!
      pull_request.status(state: 'success', name: name, description: 'Not Required')
    end
  end
end
