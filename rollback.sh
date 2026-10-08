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

if ! sudo test -f "$STATE_FILE"; then
    die "No Arch Privacy Setup rollback state was found."
fi

errors=0

log "Restoring previous NetworkManager connection settings..."

while IFS=$'	' read -r uuid property encoded; do
    [ -n "$uuid" ] || continue
    old="$(printf "%s" "$encoded" | base64 -d)" || {
        warn "Could not decode saved value for $uuid / $property"
        errors=$((errors+1))
        continue
    }

    if ! nmcli connection show "$uuid" >/dev/null 2>&1; then
        warn "Connection profile no longer exists: $uuid"
        errors=$((errors+1))
        continue
    fi

    if ! sudo nmcli connection modify "$uuid" "$property" "$old"; then
        warn "Could not restore $uuid / $property"
        errors=$((errors+1))
    fi
done < <(sudo tac "$STATE_FILE")

if sudo test -f "$STATE_DIR/config.tsv"; then
    IFS=$'	' read -r existed encoded < "$STATE_DIR/config.tsv" || {
        warn "Could not read saved NetworkManager configuration state."
        errors=$((errors+1))
        existed=""
    }

    if [ "$existed" = "1" ]; then
        tmp="$(mktemp)"
        if printf "%s" "$encoded" | base64 -d > "$tmp"; then
            if ! sudo install -m 0644 "$tmp" "$CONFIG_FILE"; then
                warn "Could not restore NetworkManager configuration."
                errors=$((errors+1))
            fi
        else
            warn "Could not decode saved NetworkManager configuration."
            errors=$((errors+1))
        fi
        rm -f "$tmp"
    elif [ "$existed" = "0" ]; then
        sudo rm -f "$CONFIG_FILE" || {
            warn "Could not remove project NetworkManager configuration."
            errors=$((errors+1))
        }
    fi
fi

sudo nmcli general reload conf >/dev/null 2>&1 || warn "NetworkManager configuration reload failed."

if [ "$errors" -eq 0 ]; then
    sudo rm -rf "$STATE_DIR"
    log "Rollback complete."
    log "Existing connections were not forcibly disconnected."
    log "Reconnect the affected Wi-Fi/Ethernet profile if needed."
else
    warn "Rollback completed with $errors error(s). State was preserved for another rollback attempt."
    exit 1
fi
