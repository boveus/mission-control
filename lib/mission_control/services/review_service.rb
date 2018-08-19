module MissionControl::Services
  module ReviewService
    extend self
    def review(event_type, payload)
      return unless ['pull_request', 'pull_request_review'].include?(event_type)

      pull_request = MissionControl::Models::PullRequest.new(event_type: event_type, payload: payload)
      MissionControl::Models::Control.execute!(pull_request: pull_request)
    end
  end
end
