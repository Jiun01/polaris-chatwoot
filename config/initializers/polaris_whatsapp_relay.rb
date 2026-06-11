# Polaris functional patch: forward non-message WhatsApp webhooks to Polaris.
#
# Prepends Polaris::WhatsappRelay onto the stock Webhooks::WhatsappController so
# the upstream controller file is never edited. `to_prepare` re-applies the
# prepend on boot and on each code reload; Module#prepend is idempotent, so a
# repeated prepend is a no-op. This means the patch survives upstream Chatwoot
# upgrades with no whitelabel sweep to re-run.
Rails.application.config.to_prepare do
  Webhooks::WhatsappController.prepend(Polaris::WhatsappRelay)
end
