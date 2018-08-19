require './lib/mission_control'

class MissionControlApp < Sinatra::Base
  use Rack::Lint
  use Rack::Runtime

  get '/' do
    haml :index
  end

  post '/hooks/github' do
    event_type = request.env['HTTP_X_GITHUB_EVENT']
    payload_body = request.body.read
    request_json = JSON.parse(payload_body)

    signature = request.env['HTTP_X_HUB_SIGNATURE']

    halt 403 unless MissionControl::Services::GithubService.valid_signature?(signature, payload_body)

    MissionControl::Services::ReviewService.review(event_type, request_json)
    status 200
  end
end
