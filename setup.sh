#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[ "${EUID:-$(id -u)}" -ne 0 ] || { echo "[X] Run as a normal user." >&2; exit 1; }
source "$ROOT/lib/common.sh"
source "$ROOT/lib/mac.sh"
require_command sudo
require_command nmcli
require_command systemctl
nmcli general status >/dev/null 2>&1 || die "NetworkManager is not available."
log "Applying NetworkManager-native MAC randomization..."
configure_mac_profiles
sudo nmcli general reload conf >/dev/null
log "Existing connections were not forcibly restarted."
log "Random MACs will be used when affected connections are activated."
log "Explicit MAC policies were preserved."
log "Phase 1 configuration complete."
