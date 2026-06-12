# frozen_string_literal: true

require 'rails_helper'

# Spec for Polaris::Internal::InboxTokensController — the internal endpoint the
# Polaris admin "Add channel" flow calls to mirror a channel's outbound token.
RSpec.describe 'Polaris::Internal::InboxTokens', type: :request do
  let(:account) { create(:account) }
  let(:internal_token) { 'polaris-internal-test-secret' }

  def internal_headers(token)
    { 'X-Polaris-Internal-Token' => token }
  end

  around do |example|
    original = ENV.fetch('POLARIS_INTERNAL_TOKEN', nil)
    ENV['POLARIS_INTERNAL_TOKEN'] = internal_token
    example.run
    ENV['POLARIS_INTERNAL_TOKEN'] = original
  end

  describe 'GET /internal/inboxes/:id/token' do
    let(:channel) do
      create(:channel_facebook_page, account: account, page_access_token: 'EAA-page-token')
    end
    let(:inbox) { channel.inbox }

    context 'with a valid internal token' do
      it 'returns the Facebook Page access token' do
        get "/internal/inboxes/#{inbox.id}/token",
            params: { account_id: account.id },
            headers: internal_headers(internal_token)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['token']).to eq('EAA-page-token')
      end
    end

    context 'with a missing or wrong internal token' do
      it 'returns 401 for a wrong token' do
        get "/internal/inboxes/#{inbox.id}/token",
            params: { account_id: account.id },
            headers: internal_headers('wrong-secret')

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 when the header is absent' do
        get "/internal/inboxes/#{inbox.id}/token", params: { account_id: account.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the inbox does not exist' do
      it 'returns 404' do
        get '/internal/inboxes/999999/token',
            params: { account_id: account.id },
            headers: internal_headers(internal_token)

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq('inbox_not_found')
      end
    end
  end
end
