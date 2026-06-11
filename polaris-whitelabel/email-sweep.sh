#!/usr/bin/env bash
# Polaris whitelabel — email/mailer brand sweep. RE-RUNNABLE on every Chatwoot upgrade.
# Scrubs user-facing "Chatwoot" from mailer layouts, views, subjects, and sender fallbacks.
# PascalCase class refs (ChatwootMarkdownRenderer) and namespace refs (Chatwoot::) are
# preserved: the view-body pattern Chatwoot(?![A-Za-z]) only flips the standalone brand
# word; .rb files use exact-string edits, never a broad replace.
set -euo pipefail
ROOT="${1:-.}"; cd "$ROOT"

# 1. Sender from-address fallback (exact, 4 files): name + chatwoot.com address -> Polaris/support
for f in app/mailers/conversation_reply_mailer.rb app/mailers/application_mailer.rb \
         app/presenters/mail_presenter.rb config/initializers/devise.rb; do
  [ -f "$f" ] && perl -CSD -i -pe 's/Chatwoot <accounts\@chatwoot\.com>/Polaris <support\@getpolaris.my>/g' "$f"
done

# 2. Devise confirmation brand fallback:  || 'Chatwoot'  ->  || 'Polaris'
perl -CSD -i -pe "s/\Q|| 'Chatwoot'\E/|| 'Polaris'/g" app/views/devise/mailer/confirmation_instructions.html.erb

# 3. Mailer base layout brand_name literal (footer "Powered by {{ brand_name }}")
perl -CSD -i -pe "s/'Chatwoot'/'Polaris'/g" app/views/layouts/mailer/base.liquid

# 4. Account-notification subjects (.rb) — exact phrase only, never class names
perl -CSD -i -pe 's/Your Chatwoot account/Your Polaris account/g' \
  app/mailers/administrator_notifications/account_notification_mailer.rb

# 5. Mailer VIEW bodies (.liquid/.erb): brand word (class-safe) + any chatwoot.com support address
mapfile -t VIEWS < <(find app/views/mailers app/views/devise/mailer -type f 2>/dev/null)
if [ "${#VIEWS[@]}" -gt 0 ]; then
  perl -CSD -i -pe '
    s/Chatwoot(?![A-Za-z])/Polaris/g;
    s/(hello|accounts|support|sales)\@chatwoot\.com/support\@getpolaris.my/g;
  ' "${VIEWS[@]}"
fi
echo "email sweep done."
