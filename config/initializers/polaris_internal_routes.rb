# frozen_string_literal: true

# Polaris functional patch: register the internal channel-token route WITHOUT
# editing the upstream config/routes.rb. `prepend` inserts the route ahead of
# the application's own route set so it is matched before any catch-all, and —
# like config/initializers/polaris_whatsapp_relay.rb — leaves the upstream
# routes file PRISTINE across Chatwoot upgrades (nothing for a whitelabel sweep
# to re-apply). The path is unique (`/internal/inboxes/:id/token`) so prepending
# cannot shadow an existing route.
#
# See Polaris::Internal::InboxTokensController for the contract + auth model.
Rails.application.routes.prepend do
  get 'internal/inboxes/:id/token',
      to: 'polaris/internal/inbox_tokens#show',
      defaults: { format: :json }
end
