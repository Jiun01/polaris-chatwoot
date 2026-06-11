require 'rails_helper'

RSpec.describe Webhooks::PolarisRelayJob do
  describe '.relay_targets' do
    it 'returns [] for an inbound message webhook (Chatwoot handles it natively)' do
      payload = { 'entry' => [{ 'changes' => [
        { 'field' => 'messages', 'value' => { 'messages' => [{ 'id' => 'wamid.1' }] } }
      ] }] }
      expect(described_class.relay_targets(payload)).to eq([])
    end

    it 'returns wa-status for a delivery/read status webhook' do
      payload = { 'entry' => [{ 'changes' => [
        { 'field' => 'messages', 'value' => { 'statuses' => [{ 'id' => 'wamid.1', 'status' => 'delivered' }] } }
      ] }] }
      expect(described_class.relay_targets(payload)).to eq(['/v1/webhooks/wa-status'])
    end

    it 'returns meta-template-status for a template lifecycle webhook' do
      payload = { 'entry' => [{ 'changes' => [
        { 'field' => 'message_template_status_update', 'value' => { 'event' => 'APPROVED' } }
      ] }] }
      expect(described_class.relay_targets(payload)).to eq(['/v1/webhooks/meta-template-status'])
    end

    it 'returns wa-account for an MM-Lite account_update webhook' do
      payload = { 'entry' => [{ 'changes' => [
        { 'field' => 'account_update', 'value' => { 'event' => 'ONBOARDING_COMPLETED' } }
      ] }] }
      expect(described_class.relay_targets(payload)).to eq(['/v1/webhooks/wa-account'])
    end

    it 'handles symbol-keyed payloads (ActionController params)' do
      payload = { entry: [{ changes: [{ field: 'account_update', value: { event: 'AD_ACCOUNT_LINKED' } }] }] }
      expect(described_class.relay_targets(payload)).to eq(['/v1/webhooks/wa-account'])
    end

    it 'de-duplicates repeated targets across entries' do
      payload = { 'entry' => [
        { 'changes' => [{ 'field' => 'messages', 'value' => { 'statuses' => [{ 'id' => 'a', 'status' => 'sent' }] } }] },
        { 'changes' => [{ 'field' => 'messages', 'value' => { 'statuses' => [{ 'id' => 'b', 'status' => 'read' }] } }] }
      ] }
      expect(described_class.relay_targets(payload)).to eq(['/v1/webhooks/wa-status'])
    end
  end

  describe '#perform' do
    subject(:relay) { described_class.new }

    let(:raw_body) { '{"object":"whatsapp_business_account"}' }
    let(:signature) { 'sha256=abc123' }
    let(:base) { 'https://api.polaris.test' }

    it 'is dormant (no HTTP call) when POLARIS_RELAY_BASE_URL is unset' do
      with_modified_env POLARIS_RELAY_BASE_URL: nil do
        expect(HTTParty).not_to receive(:post)
        relay.perform('/v1/webhooks/wa-status', raw_body, signature)
      end
    end

    it 'forwards the raw body + original signature header to the Polaris endpoint' do
      with_modified_env POLARIS_RELAY_BASE_URL: base do
        expect(HTTParty).to receive(:post).with(
          'https://api.polaris.test/v1/webhooks/wa-status',
          hash_including(
            body: raw_body,
            headers: hash_including(
              'Content-Type' => 'application/json',
              'X-Hub-Signature-256' => signature
            )
          )
        ).and_return(double(code: 200))
        relay.perform('/v1/webhooks/wa-status', raw_body, signature)
      end
    end

    it 'omits the signature header when none was provided' do
      with_modified_env POLARIS_RELAY_BASE_URL: base do
        expect(HTTParty).to receive(:post).with(
          anything,
          hash_including(headers: hash_not_including('X-Hub-Signature-256'))
        ).and_return(double(code: 200))
        relay.perform('/v1/webhooks/wa-status', raw_body, nil)
      end
    end

    it 'raises RelayError on a 5xx response (so the job retries)' do
      with_modified_env POLARIS_RELAY_BASE_URL: base do
        allow(HTTParty).to receive(:post).and_return(double(code: 503))
        expect { relay.perform('/v1/webhooks/wa-status', raw_body, signature) }
          .to raise_error(described_class::RelayError)
      end
    end

    it 'raises RelayError on a transport error (so the job retries)' do
      with_modified_env POLARIS_RELAY_BASE_URL: base do
        allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)
        expect { relay.perform('/v1/webhooks/wa-status', raw_body, signature) }
          .to raise_error(described_class::RelayError)
      end
    end

    it 'does NOT retry on a 4xx (logs and drops)' do
      with_modified_env POLARIS_RELAY_BASE_URL: base do
        allow(HTTParty).to receive(:post).and_return(double(code: 401))
        expect(Rails.logger).to receive(:warn).with(/rejected HTTP 401/)
        expect { relay.perform('/v1/webhooks/wa-status', raw_body, signature) }.not_to raise_error
      end
    end
  end

  describe 'job wiring' do
    it 'enqueues on the low queue' do
      with_modified_env POLARIS_RELAY_BASE_URL: 'https://api.polaris.test' do
        expect { described_class.perform_later('/v1/webhooks/wa-status', '{}', 'sha256=x') }
          .to have_enqueued_job(described_class).on_queue('low')
      end
    end
  end
end
