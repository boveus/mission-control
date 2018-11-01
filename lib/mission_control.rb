require 'bundler'
Bundler.require(:default)
require 'active_support/all'
require 'yaml'

Dotenv.load

module MissionControl
  CONFIG_FILE = '.mission-control.yml'.freeze
end

Dir[File.dirname(__FILE__) + '/mission_control/**/*.rb'].each { |file| require file }
