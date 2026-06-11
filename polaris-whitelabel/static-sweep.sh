#!/usr/bin/env bash
# Polaris whitelabel — static metadata / SDK / color sweep. RE-RUNNABLE.
# Brand blue #1f93ff -> slate-800 #1f2937. Brand word Chatwoot(?![A-Za-z]) -> Polaris
# only in safe (non-Ruby) file types so class names/namespaces are never touched.
set -euo pipefail
ROOT="${1:-.}"; cd "$ROOT"

# 1. npm package name (cosmetic)
perl -CSD -i -pe 's{"\@chatwoot/chatwoot"}{"\@polaris/polaris"}g' package.json

# 2. PWA manifest: brand + theme/background colors
perl -CSD -i -pe 's/"Chatwoot"/"Polaris"/g; s/#1f93ff/#1f2937/gi' public/manifest.json

# 3. HTML shell meta colors (msapplication-TileColor + theme-color)
perl -CSD -i -pe 's/#1f93ff/#1f2937/gi' app/views/layouts/vueapp.html.erb

# 4. Public widget SDK default bubble color (customer-embedded)
perl -CSD -i -pe 's/#1f93ff/#1f2937/gi' app/javascript/sdk/sdk.js

# 5. Onboarding + super-admin login pages (titles, logo alt, welcome copy)
perl -CSD -i -pe 's/Chatwoot(?![A-Za-z])/Polaris/g' \
  app/views/installation/onboarding/index.html.erb \
  app/views/super_admin/devise/sessions/new.html.erb

# 6. Swagger / OpenAPI (developer-facing): brand word + cloud URLs + contact email
perl -CSD -i -pe '
  s/Chatwoot(?![A-Za-z])/Polaris/g;
  s{https?://app\.chatwoot\.com}{https://app.getpolaris.my}g;
  s/hello\@chatwoot\.com/support\@getpolaris.my/g;
' swagger/swagger.json

echo "static sweep done."
