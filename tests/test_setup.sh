#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$ROOT/setup.sh" "$ROOT/lib/common.sh" "$ROOT/lib/mac.sh"
grep -q '802-11-wireless.cloned-mac-address random' "$ROOT/lib/mac.sh"
grep -q '802-3-ethernet.cloned-mac-address random' "$ROOT/lib/mac.sh"
grep -q 'nmcli general reload conf' "$ROOT/setup.sh"
if grep -Eq 'macchanger|nft flush ruleset|systemctl restart NetworkManager' "$ROOT/setup.sh" "$ROOT/lib/"*.sh; then exit 1; fi
echo "Phase 1 static validation passed."
