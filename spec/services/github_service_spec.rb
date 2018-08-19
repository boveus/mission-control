require 'spec_helper'

describe MissionControl::Services::GithubService do
  let(:github_service) { MissionControl::Services::GithubService }
  let(:payload) { 'PAYLOAD' }

  describe '.valid_signature?' do
    before { ENV['MISSION_CONTROL_GITHUB_WEBHOOK_SECRET'] = 'secret' }

    it 'valid' do
      expect(github_service.valid_signature?('sha1=97852c90ab1a39016197d036e457aac8ffd457d5', payload)).to be true
    end

    it 'invalid' do
      expect(github_service.valid_signature?('invalid', payload)).to be false
    end
  end
end
