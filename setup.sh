#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
[ "$(id -u)" -ne 0 ] || { echo "[X] Run as a normal user." >&2; exit 1; }

source "$ROOT/lib/common.sh"
source "$ROOT/lib/state.sh"
source "$ROOT/lib/mac.sh"
source "$ROOT/lib/privacy.sh"

require_command sudo
require_command nmcli
require_command systemctl
require_command base64
require_command tac
require_command flock

nmcli general status >/dev/null 2>&1 || die "NetworkManager is not available."
systemctl is-active --quiet systemd-resolved || die "systemd-resolved must be active for encrypted DNS. No changes were made."

acquire_lock

if sudo test -e "$STATE_DIR"; then
    die "An existing rollback state was found. Run ./rollback.sh first; refusing to overwrite it."
fi

# No changes have been made before this point. If backup creation fails,
# leave the system untouched instead of attempting a partial rollback.
state_init
state_backup_config

rollback_on_error() {
    warn "Setup failed. Starting automatic rollback..."
    ARCH_PRIVACY_SETUP_LOCK_HELD=1 "$ROOT/rollback.sh" || warn "Automatic rollback also failed. Use ./rollback.sh manually."
}
trap rollback_on_error ERR

on_interrupt() {
    warn "Setup interrupted. Rollback state was preserved in $STATE_DIR."
    exit 130
}
trap on_interrupt INT TERM

log "Applying NetworkManager-native MAC privacy..."
configure_mac_profiles

log "Applying Wi-Fi scan privacy, encrypted Quad9 DNS, DHCP privacy, IPv6 privacy, and local discovery hardening..."
configure_scan_privacy
configure_connection_privacy

sudo nmcli general reload conf >/dev/null

log "Running read-only verification..."
"$ROOT/audit.sh"

log "Privacy setup applied."
log "Active connections were not forcibly restarted."
log "Reconnection/reboot is required for connection-activation settings to fully take effect."
log "If networking becomes unusable, run: ./rollback.sh"
log "Phase implementation complete; real hardware validation remains."
