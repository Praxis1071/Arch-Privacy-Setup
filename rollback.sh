#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
source "$ROOT/lib/common.sh"
source "$ROOT/lib/state.sh"

[ "$(id -u)" -ne 0 ] || die "Run as a normal user; sudo is used internally."
require_command sudo
require_command nmcli
require_command base64
require_command tac

if ! sudo test -s "$STATE_FILE"; then
    die "No Arch Privacy Setup rollback state was found."
fi

log "Restoring previous NetworkManager connection settings..."

while IFS=$'\t' read -r uuid property encoded; do
    [ -n "$uuid" ] || continue
    old="$(printf "%s" "$encoded" | base64 -d)"
    sudo nmcli connection modify "$uuid" "$property" "$old"
done < <(sudo tac "$STATE_FILE")

if sudo test -f "$STATE_DIR/config.tsv"; then
    IFS=$'\t' read -r existed encoded < "$STATE_DIR/config.tsv"
    if [ "$existed" = "1" ]; then
        tmp="$(mktemp)"
        printf "%s" "$encoded" | base64 -d > "$tmp"
        sudo install -m 0644 "$tmp" "$CONFIG_FILE"
        rm -f "$tmp"
    else
        sudo rm -f "$CONFIG_FILE"
    fi
fi

sudo nmcli general reload conf >/dev/null 2>&1 || true
sudo systemctl try-reload-or-restart systemd-resolved.service >/dev/null 2>&1 || true
sudo rm -rf "$STATE_DIR"

log "Rollback complete."
log "Existing connections were not forcibly disconnected."
log "Reconnect the affected Wi-Fi/Ethernet profile if needed."
