ENV['RACK_ENV'] ||= 'development'

require './mission_control_app'

# sync stdout so puts shows in heroku logs
$stdout.sync = true

map '/' do
  run MissionControlApp
end
