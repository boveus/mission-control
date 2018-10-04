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

  let(:review) do
    {
      id: '123456789',
      user: { login: 'aterris' },
      state: 'APPROVED',
      submitted_at: '2018-03-01 10:00:00 UTC'
    }
  end

  let(:commit) do
    {
      sha: 'abc123',
      commit: { committer: { date: '2018-02-01 10:00:00 UTC' } },
      files: [
        { sha: 'def456', filename: 'lib/mission_control.rb' },
        { sha: 'ghi789', filename: 'README.md' }
      ]
    }
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

  describe '#last_commit' do
    specify do
      expect(pull_request.last_commit).to eq('abc123')
    end
  end

  describe '#commits' do
    specify do
      allow(github_stub).to receive(:pull_request_commits).and_return([commit])
      expect(pull_request.commits).to eq([commit])
    end
  end

  describe '#base_branch' do
    specify do
      expect(pull_request.base_branch).to eq('base_branch')
    end
  end

  describe '#reviews' do
    specify do
      allow(github_stub).to receive(:pull_request_reviews).and_return([review])
      expect(pull_request.reviews).to eq([review])
    end
  end

  describe '#approved_reviews' do
    let(:approvals) { [] }

    before do
      allow(github_stub).to receive(:pull_request_reviews).and_return(approvals)
    end

    context 'no approvals' do
      let(:approvals) { [] }

      it 'no approvals' do
        expect(pull_request.approved_reviews).to eq([])
      end
    end

    context 'multiple approvals' do
      context 'approve' do
        let(:approvals) do
          [
            { :state => 'APPROVED', :user => { :login => 'jperalta' } },
            { :state => 'APPROVED', :user => { :login => 'asantiago' } }
          ]
        end

        it 'two approvals' do
          expect(pull_request.approved_reviews).to eq(approvals)
        end
      end
    end

    context 'single approval' do
      context 'approve, reject' do
        let(:approvals) do
          [
            { :state => 'APPROVED', :user => { :login => 'jperalta' } },
            { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'no approvals' do
          expect(pull_request.approved_reviews).to eq([])
        end
      end

      context 'approve, comment' do
        let(:approvals) do
          [
            { :state => 'APPROVED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'one approval' do
          expect(pull_request.approved_reviews).to eq([approvals.first])
        end
      end

      context 'reject, approve' do
        let(:approvals) do
          [
            { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } },
            { :state => 'APPROVED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'one approval' do
          expect(pull_request.approved_reviews).to eq([approvals[1]])
        end
      end

      context 'reject, comment' do
        let(:approvals) do
          [
            { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'no approvals' do
          expect(pull_request.approved_reviews).to eq([])
        end
      end

      context 'approve, comment, reject, comment' do
        let(:approvals) do
          [
            { :state => 'APPROVED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } },
            { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'no approvals' do
          expect(pull_request.approved_reviews).to eq([])
        end
      end

      context 'reject, comment, approve, comment' do
        let(:approvals) do
          [
            { :state => 'CHANGES_REQUESTED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } },
            { :state => 'APPROVED', :user => { :login => 'jperalta' } },
            { :state => 'COMMENTED', :user => { :login => 'jperalta' } }
          ]
        end

        it 'one approval' do
          expect(pull_request.approved_reviews).to eq([approvals[2]])
        end
      end
    end
  end

  describe 'approvals' do
    let(:approvals) do
      [
        { :state => 'APPROVED', :user => { :login => 'jperalta' } },
        { :state => 'APPROVED', :user => { :login => 'asantiago' } }
      ]
    end

    specify do
      allow(pull_request).to receive(:approved_reviews).and_return(approvals)
      expect(pull_request.approvals).to eq(%w[jperalta asantiago])
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

  describe '#new_commits' do
    context 'no commits, no reviews' do
      specify do
        allow(pull_request).to receive(:reviews).and_return([])
        allow(pull_request).to receive(:commits).and_return([])

        expect(pull_request.new_commits).to eq([])
      end
    end

    context 'commits with no reviews' do
      specify do
        allow(pull_request).to receive(:reviews).and_return([])
        allow(pull_request).to receive(:commits).and_return([commit])

        expect(pull_request.new_commits).to eq([commit])
      end
    end

    context 'commits with review after' do
      specify do
        allow(pull_request).to receive(:reviews).and_return([review])
        allow(pull_request).to receive(:commits).and_return([commit])

        expect(pull_request.new_commits).to eq([])
      end
    end

    context 'commits after a review' do
      let(:review) do
        {
          id: '123456789',
          user: { login: 'aterris' },
          state: 'APPROVED',
          submitted_at: '2018-01-02 10:00:00 UTC'
        }
      end

      let(:prior_commit) do
        {
          sha: 'abc123',
          commit: { committer: { date: '2018-01-01 10:00:00 UTC' } },
          files: [
            { sha: 'def456', filename: 'lib/mission_control.rb' },
            { sha: 'ghi789', filename: 'README.md' }
          ]
        }
      end

      specify do
        allow(pull_request).to receive(:reviews).and_return([review])
        allow(pull_request).to receive(:commits).and_return([prior_commit, commit])

        expect(pull_request.new_commits).to eq([commit])
      end
    end
  end

  describe '#changed_files' do
    context 'no new commits' do
      specify do
        allow(pull_request).to receive(:new_commits).and_return([])

        expect(pull_request.changed_files).to eq([])
      end
    end

    context 'new commits with changed files' do
      let(:another_commit) do
        {
          sha: 'jkl123',
          commit: { committer: { date: '2018-02-02 10:00:00 UTC' } },
          files: [
            { sha: 'mno456', filename: 'spec/mission_control_spec.rb' },
            { sha: 'pqr789', filename: 'README.md' }
          ]
        }
      end

      specify do
        allow(pull_request).to receive(:new_commits).and_return([commit, another_commit])
        allow(github_stub).to receive(:commit).and_return(commit, another_commit)

        expect(pull_request.changed_files).to eq(%w[/lib/mission_control.rb /README.md /spec/mission_control_spec.rb])
      end
    end
  end

  describe '#status' do
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

  describe '#dismiss' do
    it 'dismisses a review and re-requests reviews' do
      expect(github_stub).to receive(:dismiss_pull_request_review).with(
        'calendly/mission-control', '23', '123456789', 'Dismissed by Mission Control'
      )

      expect(github_stub).to receive(:pull_request_reviews).with(
        'calendly/mission-control', '23', :accept => 'application/vnd.github.v3+json'
      )
      pull_request.dismiss([review])
    end
  end
end
