require 'spec_helper'

describe MissionControl::Models::Control do
  before do
    allow(STDOUT).to receive(:puts)
  end

  let(:payload) do
    {
      'action' => 'synchronize',
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
      state: 'APPROVED'
    }
  end

  let(:name) { 'Code Review' }
  let(:users) { ['aterris'] }
  let(:paths) { '*' }
  let(:count) { 1 }
  let(:dismissal_paths) { '*' }
  let(:dismiss) { nil }

  let(:control) do
    MissionControl::Models::Control.new(
      pull_request: pull_request,
      name: name,
      users: users,
      paths: paths,
      count: count,
      dismissal_paths: dismissal_paths,
      dismiss_enabled: dismiss
    )
  end

  describe '::fetch' do
    let(:github_stub) { double('github') }
    before do
      allow(MissionControl::Services::GithubService).to receive(:client).and_return(github_stub)

      config_file = File.read('spec/fixtures/.mission-control.yml')
      allow(github_stub).to receive(:content).and_return(:content => Base64.encode64(config_file))
      allow(pull_request).to receive(:update_with_master?).and_return(false)
    end

    it 'skip if no config file found in the repo' do
      allow(github_stub).to receive(:content).and_return(nil)
      expect(MissionControl::Models::Control).to_not receive(:new)

      MissionControl::Models::Control.fetch(pull_request: pull_request)
    end

    it 'fetches controls from repo' do
      expect(github_stub).to receive(:content).with(
        'calendly/mission-control',
        :path => '.mission-control.yml',
        :ref => 'base_branch'
      )

      controls = MissionControl::Models::Control.fetch(pull_request: pull_request)

      expect(controls.length).to eq(3)
    end

    it 'maps data to controls correctly' do
      controls = MissionControl::Models::Control.fetch(pull_request: pull_request)

      expect(controls.first.name).to eq('Code Review')
      expect(controls.first.users).to eq(%w[cboyle jperalta])
      expect(controls.first.paths).to eq('*')
      expect(controls.first.count).to eq(2)
      expect(controls.first.dismissal_paths).to eq('*')
    end
  end

  describe '::execute!' do
    let(:code_review_control) { double('control') }
    let(:qa_review_control) { double('control') }

    before do
      allow(MissionControl::Models::Control).to receive(:fetch).and_return([code_review_control, qa_review_control])
    end

    it 'skips execution if no config file is found' do
      allow(MissionControl::Models::Control).to receive(:fetch).and_return(nil)

      expect(code_review_control).to_not receive(:execute!)
      expect(code_review_control).to_not receive(:dismiss_reviews!)
      expect(qa_review_control).to_not receive(:execute!)
      expect(qa_review_control).to_not receive(:dismiss_reviews!)

      MissionControl::Models::Control.execute!(pull_request: pull_request)
    end

    it 'executes and dissmisses reviews for all controls' do
      expect(code_review_control).to receive(:execute!)
      expect(code_review_control).to receive(:dismiss_reviews!)
      expect(qa_review_control).to receive(:execute!)
      expect(qa_review_control).to receive(:dismiss_reviews!)

      MissionControl::Models::Control.execute!(pull_request: pull_request)
    end
  end

  describe '#initialize' do
    let(:dismissal_paths) { nil }
    it 'dismissal path defaults to paths' do
      expect(control.dismissal_paths).to eq(paths)
    end

    context 'dismiss control not set' do
      it 'defaults to true' do
        expect(control.dismiss_enabled).to be true
      end
    end

    context 'dismiss control set to false' do
      let(:dismiss) { false }
      it 'set to false' do
        expect(control.dismiss_enabled).to be false
      end
    end
  end

  describe '#active?' do
    context 'all paths' do
      let(:paths) { '*' }

      it 'active' do
        allow(pull_request).to receive(:files).and_return(['/lib/mission_control.rb'])
        expect(control.active?).to be true
      end
    end

    context 'ignored files' do
      let(:paths) { ['*', '!README.md'] }

      it 'active' do
        allow(pull_request).to receive(:files).and_return(['/lib/mission_control.rb'])
        expect(control.active?).to be true
      end

      it 'inactive' do
        allow(pull_request).to receive(:files).and_return(['/README.md'])
        expect(control.active?).to be false
      end
    end

    context 'ignored directory' do
      let(:paths) { ['*', '!specs/'] }

      it 'active' do
        allow(pull_request).to receive(:files).and_return(['/lib/mission_control.rb'])
        expect(control.active?).to be true
      end

      it 'inactive' do
        allow(pull_request).to receive(:files).and_return(['/specs/mission_control_spec.rb'])
        expect(control.active?).to be false
      end
    end
  end

  describe '#execute!' do
    context 'inactive control' do
      before do
        allow(control).to receive(:active?).and_return(false)
      end

      it 'set control approved in github' do
        expect(pull_request).to receive(:status).with(state: 'success', name: name, description: 'Not Required')
        control.execute!
      end
    end

    context 'active control' do
      before do
        allow(control).to receive(:active?).and_return(true)
      end

      context 'approved' do
        it 'set control approved in github' do
          allow(pull_request).to receive(:approvals).and_return(['aterris'])

          expect(pull_request).to receive(:status).with(
            state: 'success',
            name: name,
            description: 'Required: 1 | Approved by: aterris'
          )

          control.execute!
        end
      end

      context 'not approved' do
        it 'set control pending in github' do
          allow(pull_request).to receive(:approvals).and_return(['jperalta'])

          expect(pull_request).to receive(:status).with(
            state: 'pending',
            name: name,
            description: 'Required: 1'
          )

          control.execute!
        end
      end

      context 'not enough approvals' do
        let(:count) { 2 }

        it 'set control pending in github' do
          allow(pull_request).to receive(:approvals).and_return(['aterris'])

          expect(pull_request).to receive(:status).with(
            state: 'pending',
            name: name,
            description: 'Required: 2 | Approved by: aterris'
          )

          control.execute!
        end
      end
    end
  end

  describe '#dismissable?' do
    before do
      allow(pull_request).to receive(:update_with_master?).and_return(false)
    end

    context 'dismiss control set to false' do
      let(:dismiss) { false }
      it 'not dismissable' do
        expect(control.dismissable?).to eq false
      end
    end

    context 'pull request is update wiuth master' do
      it 'not dismissable' do
        allow(pull_request).to receive(:update_with_master?).and_return(true)
        expect(control.dismissable?).to eq false
      end
    end

    context 'all paths' do
      it 'dismissable' do
        allow(pull_request).to receive(:changed_files).and_return(['/lib/mission_control.rb'])
        expect(control.dismissable?).to be true
      end
    end

    context 'ignored paths' do
      let(:dismissal_paths) { ['*', '!README.md'] }

      context 'matching files' do
        it 'dismissable' do
          allow(pull_request).to receive(:changed_files).and_return(['/lib/mission_control.rb'])
          expect(control.dismissable?).to be true
        end
      end

      context 'no matching files' do
        it 'not dismissable' do
          allow(pull_request).to receive(:changed_files).and_return(['/README.md'])
          expect(control.dismissable?).to be false
        end
      end
    end

    context 'ignored directory' do
      let(:dismissal_paths) { ['*', '!specs/'] }

      context 'matching files' do
        it 'dismissable' do
          allow(pull_request).to receive(:changed_files).and_return(['/lib/mission_control.rb'])
          expect(control.dismissable?).to be true
        end
      end

      context 'no matching files' do
        it 'not dismissable' do
          allow(pull_request).to receive(:changed_files).and_return(['/specs/mission_control_spec.rb'])
          expect(control.dismissable?).to be false
        end
      end
    end
  end

  describe '#dismiss_reviews!' do
    context 'no reviews dismissable' do
      it 'does not execute dismissals' do
        allow(control).to receive(:dismissable?).and_return(false)

        expect(pull_request).to_not receive(:dismiss)

        control.dismiss_reviews!
      end
    end

    context 'dismissable reviews' do
      it 'does execute dismissals' do
        allow(control).to receive(:dismissable?).and_return(true)
        allow(pull_request).to receive(:approved_reviews).and_return([review])

        expect(pull_request).to receive(:dismiss).with([review])

        control.dismiss_reviews!
      end
    end
  end
end
