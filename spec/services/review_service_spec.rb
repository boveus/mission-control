require 'spec_helper'

describe MissionControl::Services::ReviewService do
  let(:review_service) { MissionControl::Services::ReviewService }

  let(:payload) { { 'action' => 'synchronize' } }

  describe('::review') do
    context 'unexpected event' do
      it 'no action' do
        expect(MissionControl::Models::PullRequest).to_not receive(:new)
        expect(MissionControl::Models::Control).to_not receive(:execute!)

        review_service.review('random_event', payload)
      end
    end

    context 'pull_request event' do
      before do
        allow(MissionControl::Models::PullRequest).to receive(:new)
        allow(MissionControl::Models::Control).to receive(:execute!)
      end

      it 'generate Pull Request Object from Webhook' do
        expect(MissionControl::Models::PullRequest).to receive(:new).with(event_type: 'pull_request', payload: payload)

        review_service.review('pull_request', payload)
      end

      it 'executs all controls' do
        expect(MissionControl::Models::Control).to receive(:execute!)

        review_service.review('pull_request', payload)
      end
    end

    context 'pull_request_review event' do
      before do
        allow(MissionControl::Models::PullRequest).to receive(:new)
        allow(MissionControl::Models::Control).to receive(:execute!)
      end

      it 'generate Pull Request Object from Webhook' do
        expect(MissionControl::Models::PullRequest).to receive(:new).with(event_type: 'pull_request', payload: payload)

        review_service.review('pull_request', payload)
      end

      it 'executs all controls' do
        expect(MissionControl::Models::Control).to receive(:execute!)

        review_service.review('pull_request', payload)
      end
    end
  end
end
