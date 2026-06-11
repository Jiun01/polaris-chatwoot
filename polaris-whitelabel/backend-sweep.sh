#!/usr/bin/env bash
# Polaris whitelabel — client-visible backend strings. RE-RUNNABLE.
# EXACT-LITERAL substitutions only: Ruby class/namespace refs (ChatwootHub,
# ChatwootApp, Chatwoot.config, ChatwootExceptionTracker) are never matched.
# Also flips ENABLE_PUSH_RELAY_SERVER default true->false (stops push phone-home).
set -euo pipefail
ROOT="${1:-.}"; cd "$ROOT"

# MFA TOTP issuer (shows in agent's Authenticator app)
perl -i -pe "s/issuer = 'Chatwoot'/issuer = 'Polaris'/" app/services/mfa/management_service.rb

# Soft-delete PII email domain
perl -i -pe "s/'\@chatwoot-deleted\.invalid'/'\@polaris-deleted.invalid'/" app/services/account_deletion_service.rb

# Push test service: title default, relay default OFF, frontend-url fallback
perl -i -pe "s/'INSTALLATION_NAME', 'Chatwoot'/'INSTALLATION_NAME', 'Polaris'/; s/ENABLE_PUSH_RELAY_SERVER', true/ENABLE_PUSH_RELAY_SERVER', false/; s{'https://app\.chatwoot\.com'}{'https://app.getpolaris.my'}g" app/services/notification/push_test_service.rb

# Push notification service: relay default OFF (no Chatwoot Hub phone-home)
perl -i -pe "s/ENABLE_PUSH_RELAY_SERVER', true/ENABLE_PUSH_RELAY_SERVER', false/" app/services/notification/push_notification_service.rb

# Super-admin metric labels + restart flash + sales email
perl -i -pe "s/'Chatwoot edition'/'Polaris edition'/; s/'Chatwoot version'/'Polaris version'/" app/controllers/super_admin/instance_statuses_controller.rb
perl -i -pe "s/Restart Chatwoot web and worker/Restart Polaris web and worker/" app/controllers/super_admin/app_configs_controller.rb app/controllers/super_admin/installation_configs_controller.rb
perl -i -pe "s/sales\@chatwoot\.com/support\@getpolaris.my/" app/views/super_admin/settings/show.html.erb

# Public controller bad-domain error (customer-facing support email)
perl -i -pe "s/support\@chatwoot\.com/support\@getpolaris.my/" app/controllers/public_controller.rb

# Dev seed canned response
perl -i -pe "s/Hello welcome to chatwoot\./Hello welcome to Polaris./" db/seeds.rb

# CRM LeadSquared brand fallback (sent to external CRM)
perl -i -pe "s/\|\| 'Chatwoot'/|| 'Polaris'/" \
  app/services/crm/leadsquared/mappers/contact_mapper.rb \
  app/services/crm/leadsquared/mappers/conversation_mapper.rb \
  app/services/crm/leadsquared/setup_service.rb

echo "backend client-visible sweep done."
