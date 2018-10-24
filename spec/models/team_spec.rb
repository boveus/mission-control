require 'spec_helper'

describe MissionControl::Models::Team do
  before do
    allow(STDOUT).to receive(:puts)
    allow(team).to receive(:github).and_return(github_stub)
  end

  let(:team) { MissionControl::Models::Team.new(team: github_team) }
  let(:github_team) { { name: 'Nine Nine', slug: 'nine-nine', id: 1234 } }
  let(:github_stub) { double('github') }
  let(:members) do
    [
      { login: 'jperalta', id: 1_111_111 },
      { login: 'asantiago', id: 2_222_222 }
    ]
  end

  describe '#id' do
    specify do
      expect(team.id).to eq(1234)
    end
  end

  describe '#slug' do
    specify do
      expect(team.slug).to eq('nine-nine')
    end
  end

  describe '#members' do
    specify do
      allow(github_stub).to receive(:team_members).and_return(members)
      expect(team.members).to eq(members)
    end
  end
end
