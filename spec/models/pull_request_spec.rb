require 'spec_helper'

describe MissionControl::Models::PullRequest do
  before do
    allow(STDOUT).to receive(:puts)
    allow(pull_request).to receive(:github).and_return(github_stub)
  end

  let(:github_stub) { double('github') }

  let(:payload) do
    {
      'action' => action,
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
  let(:action) { 'pull_request' }

  let(:pull_request) do
    MissionControl::Models::PullRequest.new(
      event_type: 'pull_request',
      payload: payload
    )
  end

  let(:review) do
    {
      id: '123456789',
      commit_id: review_commit_id,
      user: { login: 'aterris' },
      state: 'APPROVED',
      submitted_at: submitted_at_date
    }
  end
  let(:review_commit_id) { 'abc123' }
  let(:submitted_at_date) { '2018-03-01 10:00:00 UTC' }

  let(:commit) do
    {
      sha: commit_sha,
      commit: { committer: { date: committer_date } },
      parents: parents,
      files: files
    }
  end
  let(:commit_sha) { 'abc123' }
  let(:committer_date) { '2018-02-01 10:00:00 UTC' }
  let(:parents) do
    [
      { sha: 'head_commit_sha' },
      { sha: 'base_commit_sha' }
    ]
  end
  let(:files) do
    [
      { sha: 'def456', filename: 'lib/mission_control.rb' },
      { sha: 'ghi789', filename: 'README.md' }
    ]
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

  describe '#last_commit_sha' do
    specify do
      expect(pull_request.last_commit_sha).to eq('abc123')
    end
  end

  describe '#last_commit' do
    it 'should return commit' do
      allow(github_stub).to receive(:commit).and_return(commit)
      expect(pull_request.last_commit).to eq(commit)
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

  describe '#last_base_branch_commit' do
    it 'should return last commit of the base branch' do
      allow(github_stub).to receive(:commits).and_return([commit])
      expect(pull_request.last_base_branch_commit).to eq(commit)
    end
  end

  describe '#reviews' do
    specify do
      allow(github_stub).to receive(:pull_request_reviews).and_return([review])
      expect(pull_request.reviews).to eq([review])
    end
  end

  describe '#update_with_master?' do
    let(:action) { 'synchronize' }
    let(:last_base_commit) { { sha: 'base_commit_sha' } }

    before do
      allow(github_stub).to receive(:commit).and_return(commit)
      allow(github_stub).to receive(:commits).and_return([last_base_commit])
    end

    context 'is true' do
      specify do
        expect(pull_request.update_with_master?).to be true
      end
    end

    context 'is false' do
      context 'action is not synchronize' do
        let(:action) { 'pull_request' }

        specify do
          expect(pull_request.update_with_master?).to be false
        end
      end

      context 'commit is not a merge commit with 2 parents' do
        let(:parents) do
          [{ sha: 'single_parent_sha' }]
        end
        specify do
          expect(pull_request.update_with_master?).to be false
        end
      end

      context 'parent commits do not contain last commit of base branch' do
        let(:last_base_commit) { { sha: 'a_different_base_commit_sha' } }

        specify do
          expect(pull_request.update_with_master?).to be false
        end
      end
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
    let(:reviews) { [] }
    let(:commits) { [] }

    before do
      allow(pull_request).to receive(:reviews).and_return(reviews)
      allow(pull_request).to receive(:commits).and_return(commits)
    end

    context 'no reviews' do
      context 'no commits, no reviews' do
        specify do
          expect(pull_request.new_commits).to eq([])
        end
      end

      context 'commits with no reviews' do
        let(:commits) { [commit] }

        specify do
          expect(pull_request.new_commits).to eq([commit])
        end
      end
    end

    context 'reviews' do
      let(:reviews) { [review] }
      let(:commits) { [commit, another_commit] }
      let(:another_commit) { { sha: 'another_commit_sha' } }

      context 'commits with review after' do
        let(:review_commit_id) { commit_sha }

        specify do
          expect(pull_request.new_commits).to eq([another_commit])
        end
      end

      context 'commits prior to review' do
        let(:review_commit_id) { 'another_commit_sha' }

        specify do
          expect(pull_request.new_commits).to eq([])
        end
      end

      context 'review with different commit sha' do
        let(:review_commit_id) { 'no_matching_sha' }

        specify do
          expect(pull_request.new_commits).to eq(commits)
        end
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

      pull_request.dismiss([review])

      expect(pull_request.instance_variable_get(:@reviews)).to be_nil
    end
  end
end
