module MissionControl::Models
  class Control
    def self.fetch(pull_request:)
      github = MissionControl::Services::GithubService.client
      response = github.content(pull_request.repo, :path => MissionControl::CONFIG_FILE)
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

      puts "Executing #{controls.length} Controls for #{pull_request.repo}"
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
      return unless active?

      approvals = (pull_request.approvals & users)

      state = approvals.length < count ? 'pending' : 'success'
      description = "#{approvals.length} of #{count}"
      description += " (#{approvals.join(', ')})" unless approvals.empty?

      pull_request.status(state: state, name: name, description: description)
    end
  end
end
