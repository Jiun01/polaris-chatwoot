#!/usr/bin/env bash
# Polaris whitelabel — external-URL + brand sweep for content/helper/route files.
# RE-RUNNABLE. Operates on an EXPLICIT file list only (never blanket) so PascalCase
# class refs and namespaces elsewhere are never touched.
#   - chwt.app/*            -> /hc/polaris-help  (internal help center root)
#   - chatwoot.com/hc|docs  -> /hc/polaris-help
#   - any other chatwoot.com -> https://getpolaris.my
#   - brand word Chatwoot(?![A-Za-z]) -> Polaris  (class-safe)
set -euo pipefail
ROOT="${1:-.}"; cd "$ROOT"

FILES=(
  app/javascript/dashboard/helper/featureHelper.js
  app/javascript/dashboard/components/Code.vue
  app/javascript/dashboard/components-next/Campaigns/EmptyState/CampaignEmptyStateContent.js
  app/javascript/dashboard/routes/dashboard/captain/assistants/Index.vue
  app/javascript/dashboard/routes/dashboard/captain/documents/Index.vue
  app/javascript/dashboard/routes/dashboard/captain/responses/Index.vue
  app/javascript/dashboard/routes/dashboard/captain/responses/Pending.vue
)
# plus all captain empty-state content/components
while IFS= read -r f; do FILES+=("$f"); done < <(find app/javascript/dashboard/components-next/captain/pageComponents/emptyStates -type f 2>/dev/null)

EXIST=()
for f in "${FILES[@]}"; do [ -f "$f" ] && EXIST+=("$f"); done
echo "url/brand sweep over ${#EXIST[@]} files"

perl -CSD -i -pe '
  s{https?://chwt\.app/[^"'\''\s)]+}{/hc/polaris-help}g;
  s{https?://(?:www\.)?chatwoot\.com/(?:hc|docs)/[^"'\''\s)]+}{/hc/polaris-help}g;
  s{https?://(?:www\.)?chatwoot\.com[^"'\''\s)]*}{https://getpolaris.my}g;
  s/Chatwoot(?![A-Za-z])/Polaris/g;
' "${EXIST[@]}"
echo "done."
