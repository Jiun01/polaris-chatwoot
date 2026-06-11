# Prepended to Webhooks::WhatsappController (see config/initializers/
# polaris_whatsapp_relay.rb) so the upstream controller file stays PRISTINE
# across Chatwoot upgrades — nothing for a whitelabel sweep to re-apply.
#
# Forwards non-message WhatsApp webhook events (delivery statuses,
# message_template_status_update, account_update) to the Polaris API. The raw
# body + original Meta `X-Hub-Signature-256` are only available here in the
# controller (the WhatsappEventsJob receives parsed params, and re-serializing
# would break Polaris's HMAC verify). Inbound messages are NOT relayed —
# Chatwoot owns those natively. See Webhooks::PolarisRelayJob.
module Polaris::WhatsappRelay
  def process_payload
    relay_non_message_events_to_polaris unless inactive_whatsapp_number?
    super
  end

  private

  def relay_non_message_events_to_polaris
    targets = Webhooks::PolarisRelayJob.relay_targets(params.to_unsafe_hash)
    return if targets.empty?

    raw_body = request.raw_post
    signature = request.headers['X-Hub-Signature-256']
    targets.each do |path|
      Webhooks::PolarisRelayJob.perform_later(path, raw_body, signature)
    end
  rescue StandardError => e
    # A relay-enqueue failure must never block native inbound processing.
    Rails.logger.error("PolarisRelay enqueue failed: #{e.class}: #{e.message}")
  end
end
