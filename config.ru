ENV['RACK_ENV'] ||= 'production'

require './mission_control_app'

if ENV['AIRBRAKE_PROJECT_ID'] && ENV['AIRBRAKE_API_KEY']
  Airbrake.configure do |config|
    config.environment = ENV['RACK_ENV']
    config.ignore_environments = %w[development test]

    config.project_id = ENV['AIRBRAKE_PROJECT_ID']
    config.project_key = ENV['AIRBRAKE_API_KEY']
    config.logger.level = Logger::INFO
  end
end

configure :test, :development do
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG
  use Rack::CommonLogger, logger
end

# sync stdout so puts shows in heroku logs
$stdout.sync = true

map '/' do
  run MissionControlApp
end
