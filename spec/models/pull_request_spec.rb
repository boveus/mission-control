require 'spec_helper'

describe MissionControl::Models::PullRequest do
  before do
    allow(STDOUT).to receive(:puts)
    allow(pull_request).to receive(:github).and_return(github_stub)
  end

  let(:github_stub) { double('github') }

  let(:payload) do
    {
      'action' => 'pull_request',
      'pull_request' => {
        'head' => { 'sha' => 'abc123', 'ref' => 'branch' },
        'number' => '23',
        'base' => { 'ref' => 'base_branch' }
      },
      'repository' => {
        'full_name' => 'calendly/mission-control'
      }
    }
  end

  let(:pull_request) do
    MissionControl::Models::PullRequest.new(
      event_type: 'pull_request',
      payload: payload
    )
  end

  describe '#repo' do
    specify do
      expect(pull_request.repo).to eq('calendly/mission-control')
    end
  end

  describe '#pr_number' do
    specify do
      expect(pull_request.pr_number).to eq('23')
    end
  end

  describe '#commit' do
    specify do
      expect(pull_request.commit).to eq('abc123')
    end
  end

  describe '#approvals' do
    let(:approvals) { [] }

    before do
      allow(github_stub).to receive(:pull_request_reviews).and_return(approvals)
    end

    context 'no approvals' do
      let(:approvals) { [] }

      it 'no approvals' do
        expect(pull_request.approvals).to eq([])
      end
    end

    context 'basic' do
      let(:approvals) do
        [
          { :state => 'APPROVED', :user => { :login => 'jperalta' } },
          { :state => 'APPROVED', :user => { :login => 'asantiago' } }
        ]
      end

      it 'two approvals' do
        expect(pull_request.approvals).to eq(%w[jperalta asantiago])
      end
    end

    context 'review changed from approved to not approved' do
      let(:approvals) do
        [
          { :state => 'APPROVED', :user => { :login => 'jperalta' } },
          { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } }
        ]
      end

      it 'no approvals' do
        expect(pull_request.approvals).to eq([])
      end
    end

    context 'review changed from not approved to approved' do
      let(:approvals) do
        [
          { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } },
          { :state => 'APPROVED', :user => { :login => 'jperalta' } }
        ]
      end

      it 'one approval' do
        expect(pull_request.approvals).to eq(['jperalta'])
      end
    end
  end

  describe 'files' do
    before do
      allow(github_stub).to receive(:pull_files).and_return([
                                                              { :filename => 'lib/mission_control.rb' },
                                                              { :filename => 'README.md' }
                                                            ])
    end

    it 'request pull request files' do
      expect(github_stub).to receive(:pull_files).with('calendly/mission-control', '23')
      pull_request.files
    end

    it 'add leading slash' do
      files = pull_request.files

      expect(files[0]).to eq('/lib/mission_control.rb')
      expect(files[1]).to eq('/README.md')
    end
  end

  describe 'status' do
    it 'create github status' do
      expect(github_stub).to receive(:create_status).with(
        'calendly/mission-control',
        'abc123',
        'success',
        context: 'mission-control/code-review',
        description: '1 of 1 (jperalta)'
      )

      pull_request.status(state: 'success', name: 'code-review', description: '1 of 1 (jperalta)')
    end
  end
end
