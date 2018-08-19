require 'rspec'
require 'webmock/rspec'

spec_dir = File.expand_path(__dir__)
$LOAD_PATH.unshift(spec_dir) unless $LOAD_PATH.include? spec_dir

ENV['RACK_ENV'] ||= 'test'

Bundler.require(:default, ENV['RACK_ENV']) if defined?(Bundler)
Dotenv.overload('.env.test')

Coveralls.wear!

require File.expand_path('../mission_control_app.rb', __dir__)
require File.expand_path('../lib/mission_control', __dir__)

RSpec.configure do |config|
  config.mock_framework = :rspec
  config.formatter = :documentation
end

WebMock.disable_net_connect!(allow_localhost: true)
