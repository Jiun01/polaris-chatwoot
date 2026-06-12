# frozen_string_literal: true

# Polaris functional patch: vends a channel's OUTBOUND access token to the
# Polaris API. Registered via config/initializers/polaris_internal_routes.rb so
# the upstream config/routes.rb stays PRISTINE across Chatwoot upgrades — the
# same philosophy as Polaris::WhatsappRelay.
#
# The Polaris admin portal's "Add channel" flow auto-provisions a channel's
# token into Polaris's own encrypted tenant_secrets store by calling
#
#   GET /internal/inboxes/:id/token?account_id=:account_id
#
# with an `X-Polaris-Internal-Token` header. Chatwoot is the source of truth for
# the channel credential (set during the Embedded Signup / Instagram-Login
# onboarding); this endpoint lets Polaris mirror it so the bot can dispatch
# outbound messages without an operator hand-pasting the token.
#
# SECURITY: machine-to-machine, INTERNAL-NETWORK ONLY (chatwoot-rails:3000). The
# response carries a decrypted channel credential, so the public ingress (Caddy)
# MUST NOT proxy `/internal/*`. Auth is a constant-time compare of the header
# against ENV['POLARIS_INTERNAL_TOKEN'] (== the Polaris API's
# CHATWOOT_INTERNAL_TOKEN). The endpoint is DORMANT — 401 to every caller —
# until that env var is set, so it is safe to deploy ahead of the Polaris-side
# cutover.
module Polaris
  module Internal
    class InboxTokensController < ActionController::API
      before_action :authenticate_internal_request!

      # GET /internal/inboxes/:id/token?account_id=:account_id
      #   200 { "token": "<channel access token>" }
      #   401 (missing / wrong internal token)
      #   404 { "error": "inbox_not_found" }
      #   422 { "error": "no_token" } (channel has no resolvable outbound token)
      def show
        inbox = Inbox.find_by(account_id: params[:account_id], id: params[:id])
        return render(json: { error: 'inbox_not_found' }, status: :not_found) if inbox.nil?

        token = channel_access_token(inbox.channel)
        return render(json: { error: 'no_token' }, status: :unprocessable_entity) if token.blank?

        render json: { token: token }
      end

      private

      def authenticate_internal_request!
        expected = ENV.fetch('POLARIS_INTERNAL_TOKEN', '').to_s
        provided = request.headers['X-Polaris-Internal-Token'].to_s
        return if expected.present? &&
                  ActiveSupport::SecurityUtils.secure_compare(provided, expected)

        head :unauthorized
      end

      # Resolves the per-channel OUTBOUND credential Polaris needs to send on
      # that channel. Mirrors Polaris's _CHANNEL_TO_SECRET_KIND mapping:
      #   FacebookPage -> page_access_token              (meta_fb_page_access_token)
      #   Instagram    -> access_token                   (meta_ig_login_access_token)
      #   Whatsapp     -> provider_config['api_key']     (meta_waba_access_token; cloud API)
      # Returns nil for any other channel type; the caller maps that to 422.
      def channel_access_token(channel)
        case channel
        when Channel::FacebookPage then channel.page_access_token
        when Channel::Instagram then channel.access_token
        when Channel::Whatsapp then channel.provider_config&.dig('api_key')
        end
      end
    end
  end
end
