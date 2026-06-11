# Relays non-message WhatsApp webhook events from Chatwoot to the Polaris API.
#
# In the Chatwoot-native message architecture, Meta delivers ALL WhatsApp
# webhooks to Chatwoot. Chatwoot processes inbound *messages* natively (they
# create conversations and fire the agent bot). The non-message events below
# are meaningless to Chatwoot but drive Polaris features:
#
#   * delivery/read statuses        -> broadcast delivery tracking
#   * message_template_status_update -> template lifecycle (approve/reject/pause)
#   * account_update (MM-Lite)       -> tenant_channels.mm_lite_* state
#
# Polaris already exposes endpoints for these (/v1/webhooks/wa-status,
# /meta-template-status, /wa-account) that verify Meta's `X-Hub-Signature-256`
# over the RAW request body. We therefore forward the exact raw body + the
# original signature header unchanged, so Polaris's HMAC check passes with NO
# Polaris-side change.
#
# HTTParty (not SafeFetch) is used deliberately: the relay target is an
# operator-configured TRUSTED URL, and SafeFetch's ssrf_filter would wrongly
# block an internal Polaris address. The job is dormant until
# POLARIS_RELAY_BASE_URL is set, so it is safe to deploy ahead of the
# Meta-webhook cutover.
class Webhooks::PolarisRelayJob < ApplicationJob
  class RelayError < StandardError; end

  queue_as :low

  # Meta delivers each event to Chatwoot only once, so a dropped relay = a lost
  # delivery receipt / template update on the Polaris side. Retry transient
  # transport + 5xx failures.
  retry_on RelayError, wait: 3.seconds, attempts: 5

  TEMPLATE_PATH = '/v1/webhooks/meta-template-status'.freeze
  ACCOUNT_PATH  = '/v1/webhooks/wa-account'.freeze
  STATUS_PATH   = '/v1/webhooks/wa-status'.freeze

  RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

  TRANSPORT_ERRORS = [
    HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout,
    Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError
  ].freeze

  # Returns the de-duplicated list of Polaris endpoint paths a webhook payload
  # must be relayed to. Inbound-message webhooks (field 'messages' carrying
  # 'messages') return [] — Chatwoot owns those natively.
  def self.relay_targets(payload)
    # deep_stringify_keys recurses through arrays, so this works for both
    # symbol-keyed payloads (tests) and string-keyed ones (params.to_unsafe_hash).
    data = payload.to_h.deep_stringify_keys
    Array(data['entry']).flat_map do |entry|
      Array(entry['changes']).filter_map { |change| relay_path_for(change) }
    end.uniq
  end

  # Maps one Meta `changes[]` entry to its Polaris endpoint path, or nil for an
  # inbound message (field 'messages' carrying 'messages') — Chatwoot owns those.
  def self.relay_path_for(change)
    value = change['value'].is_a?(Hash) ? change['value'] : {}
    case change['field']
    when 'message_template_status_update' then TEMPLATE_PATH
    when 'account_update' then ACCOUNT_PATH
    when 'messages' then (STATUS_PATH if value['statuses'].present?)
    end
  end

  def perform(path, raw_body, signature)
    base = ENV.fetch('POLARIS_RELAY_BASE_URL', nil)
    return if base.blank?

    response = post_to_polaris(base, path, raw_body, signature)
    code = response.code.to_i

    raise RelayError, "Polaris relay #{path} -> HTTP #{code}" if RETRYABLE_STATUSES.include?(code)
    return if code.between?(200, 299)

    # 4xx (e.g. 401 signature mismatch) is not retryable — log and drop so the
    # job does not spin. Operator must fix META_APP_SECRET parity.
    Rails.logger.warn("PolarisRelay: #{path} rejected HTTP #{code} (not retried)")
  end

  private

  def post_to_polaris(base, path, raw_body, signature)
    headers = { 'Content-Type' => 'application/json' }
    headers['X-Hub-Signature-256'] = signature if signature.present?

    HTTParty.post(
      "#{base.chomp('/')}#{path}",
      body: raw_body,
      headers: headers,
      timeout: relay_timeout
    )
  rescue *TRANSPORT_ERRORS => e
    raise RelayError, "Polaris relay #{path} transport error: #{e.class}: #{e.message}"
  end

  def relay_timeout
    raw = GlobalConfig.get_value('WEBHOOK_TIMEOUT')
    timeout = raw.presence&.to_i
    timeout&.positive? ? timeout : 5
  end
end
