#!/usr/bin/env bash
# Polaris functional patches — RE-RUNNABLE presence check (READ-ONLY).
#
# Unlike the *-sweep.sh scripts (which re-apply perl string-substitutions to
# UPSTREAM files), functional patches are added as Polaris-ONLY files (new jobs,
# prepend modules, initializers). They never edit upstream files, so they
# survive Chatwoot upgrades automatically — there is nothing to re-substitute.
#
# This script does NOT modify anything; it verifies the functional patches are
# still present + wired after an upstream merge. Run it after every upgrade.
# Exits non-zero if any patch is missing.
set -euo pipefail
ROOT="${1:-.}"; cd "$ROOT"

fail=0
need_file() { if [ -f "$1" ]; then echo "  ok   $1"; else echo "  MISS $1"; fail=1; fi; }
need_grep() {
  if grep -q "$2" "$1" 2>/dev/null; then echo "  ok   $1 :: $3"; else echo "  MISS $1 :: $3"; fail=1; fi
}

echo "Polaris functional patches:"
echo "[non-message WhatsApp webhook relay -> Polaris]"
need_file app/jobs/webhooks/polaris_relay_job.rb
need_file app/controllers/concerns/polaris/whatsapp_relay.rb
need_file config/initializers/polaris_whatsapp_relay.rb
need_grep config/initializers/polaris_whatsapp_relay.rb \
  'Webhooks::WhatsappController.prepend(Polaris::WhatsappRelay)' 'prepend wired'

if [ "$fail" -ne 0 ]; then
  echo "FAIL: functional patch(es) missing — re-add the Polaris-only files above."
  exit 1
fi
echo "OK: all functional patches present."
