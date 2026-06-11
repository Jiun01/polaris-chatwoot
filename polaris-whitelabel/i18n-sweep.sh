#!/usr/bin/env bash
# Polaris whitelabel — i18n brand-word sweep. RE-RUNNABLE on every Chatwoot upgrade.
#
# Replaces the standalone brand word "Chatwoot" -> "Polaris" in locale VALUES across
# dashboard / widget / survey / Rails locale trees.
#
# SAFE BY CONSTRUCTION: the pattern \bChatwoot\b (capitalized, word-bounded) does NOT
# match the protected tokens, so no allow-list gymnastics are needed:
#   - UPDATE_CHATWOOT        (all-caps  -> "CHATWOOT" never matches "\bChatwoot\b")
#   - latestChatwootVersion  (camelCase -> no word boundary before/after "Chatwoot")
#   - chatwootSettings       (lowercase -> "chatwoot" never matches capitalized form)
#   - chatwoot.com URLs      (lowercase -> handled separately in the URL/hyperlink pass)
#
# Usage:  bash polaris-whitelabel/i18n-sweep.sh [REPO_ROOT]   (default: .)
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"

mapfile -t FILES < <(find \
  app/javascript/dashboard/i18n/locale \
  app/javascript/widget/i18n/locale \
  app/javascript/survey/i18n/locale \
  config/locales \
  -type f \( -name '*.json' -o -name '*.yml' \) 2>/dev/null | sort)

echo "locale files in scope: ${#FILES[@]}"
BEFORE=$(grep -rlE '\bChatwoot\b' "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
echo "files containing \\bChatwoot\\b BEFORE: ${BEFORE}"

# Protect-replace-restore. Plain (boundary-free) replace catches Latin-spaced AND
# CJK/Amharic-adjacent mentions (使用Chatwoot, ከChatwoot) that a \b pattern misses.
# Case-sensitive "Chatwoot" never touches CHATWOOT (i18n keys) or chatwoot* (lowercase
# vars/URLs); only latestChatwootVersion (capital-C camelCase) needs shielding.
perl -CSD -i -pe '
  s/latestChatwootVersion/\x00LCV\x00/g;
  s/Chatwoot/Polaris/g;
  s/\x00LCV\x00/latestChatwootVersion/g;
' "${FILES[@]}"

AFTER=$(grep -rlE '\bChatwoot\b' "${FILES[@]}" 2>/dev/null | wc -l | tr -d ' ')
echo "files containing \\bChatwoot\\b AFTER:  ${AFTER}"
echo "done."
