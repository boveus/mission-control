module MissionControl::Services
  module GithubService
    extend self
    def valid_signature?(signature, payload)
      return unless signature
      Rack::Utils.secure_compare(signature, build_signature(payload))
    end

    def client
      @client ||= Octokit::Client.new(access_token: access_token, auto_paginate: true)
    end

    private

    def build_signature(payload)
      digest = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('sha1'),
        webhook_secret,
        payload
      )
      "sha1=#{digest}"
    end

    def access_token
      ENV['MISSION_CONTROL_GITHUB_ACCESS_TOKEN']
    end

    def webhook_secret
      ENV['MISSION_CONTROL_GITHUB_WEBHOOK_SECRET']
    end
  end
end
