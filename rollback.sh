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
require_command flock

if ! sudo test -f "$STATE_FILE"; then
    die "No Arch Privacy Setup rollback state was found."
fi

if [ "${ARCH_PRIVACY_SETUP_LOCK_HELD:-0}" != "1" ]; then
    acquire_lock
fi

errors=0
reverse_state="$(mktemp)"
cleanup() {
    rm -f "$reverse_state"
}
trap cleanup EXIT

if ! sudo tac "$STATE_FILE" > "$reverse_state"; then
    die "Could not read rollback state."
fi

normalize_current() {
    local uuid="$1" property="$2" value
    case "$property" in
        ipv4.dns|ipv6.dns)
            value="$(nmcli -g "$property" connection show "$uuid" 2>/dev/null | awk 'NF' | paste -sd, - || true)"
            ;;
        *)
            value="$(nmcli -g "$property" connection show "$uuid" 2>/dev/null || true)"
            ;;
    esac
    [ "$value" = "--" ] && value=""
    printf "%s" "$value"
}

log "Restoring previous NetworkManager connection settings..."

while IFS=$'	' read -r uuid property encoded; do
    [ -n "$uuid" ] || continue

    old="$(printf "%s" "$encoded" | base64 -d --strict)" || {
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
        continue
    fi

    current="$(normalize_current "$uuid" "$property")"
    if [ "$current" != "$old" ]; then
        warn "Restored value verification failed for $uuid / $property"
        errors=$((errors+1))
    fi
done < "$reverse_state"

if sudo test -f "$STATE_DIR/config.tsv"; then
    IFS=$'	' read -r existed encoded < "$STATE_DIR/config.tsv" || {
        warn "Could not read saved NetworkManager configuration state."
        errors=$((errors+1))
        existed=""
    }

    if [ "$existed" = "1" ]; then
        tmp="$(mktemp)"
        if printf "%s" "$encoded" | base64 -d --strict > "$tmp"; then
            if ! sudo install -m 0644 "$tmp" "$CONFIG_FILE"; then
                warn "Could not restore NetworkManager configuration."
                errors=$((errors+1))
            elif ! cmp -s "$tmp" "$CONFIG_FILE"; then
                warn "NetworkManager configuration restore verification failed."
                errors=$((errors+1))
            fi
        else
            warn "Could not decode saved NetworkManager configuration."
            errors=$((errors+1))
        fi
        rm -f "$tmp"
    elif [ "$existed" = "0" ]; then
        if sudo test -e "$CONFIG_FILE" && ! sudo rm -f "$CONFIG_FILE"; then
            warn "Could not remove project NetworkManager configuration."
            errors=$((errors+1))
        fi
    else
        warn "Invalid saved NetworkManager configuration state."
        errors=$((errors+1))
    fi
fi

if ! sudo nmcli general reload conf >/dev/null 2>&1; then
    warn "NetworkManager configuration reload failed."
    errors=$((errors+1))
fi

if [ "$errors" -eq 0 ]; then
    sudo rm -rf "$STATE_DIR"
    log "Rollback complete."
    log "Existing connections were not forcibly disconnected."
    log "Reconnect the affected Wi-Fi/Ethernet profile if needed."
else
    warn "Rollback completed with $errors error(s). State was preserved for another rollback attempt."
    exit 1
fi
