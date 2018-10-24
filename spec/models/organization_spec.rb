require 'spec_helper'

describe MissionControl::Models::Organization do
  before do
    allow(STDOUT).to receive(:puts)
    allow(organization).to receive(:github).and_return(github_stub)
  end

  let(:organization) do
    MissionControl::Models::Organization.new(organization: organization_login)
  end
  let(:organization_login) { 'nypd' }
  let(:github_stub) { double('github') }
  let(:org_team) { { name: 'Nine Nine', slug: 'nine-nine', id: 5678 } }

  describe '#teams' do
    specify do
      allow(github_stub).to receive(:org_teams).and_return([org_team])
      expect(MissionControl::Models::Team).to receive(:new).with({ team: org_team })

      organization.teams
    end
  end
end
