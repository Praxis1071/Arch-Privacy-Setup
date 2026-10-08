#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/arch-privacy-setup"
STATE_FILE="$STATE_DIR/state.tsv"
CONFIG_FILE="/etc/NetworkManager/conf.d/90-arch-privacy-setup.conf"

state_init() {
    if ! sudo mkdir "$STATE_DIR" 2>/dev/null; then
        die "Could not create rollback state directory: $STATE_DIR"
    fi
    sudo chmod 0700 "$STATE_DIR"
    if ! sudo touch "$STATE_FILE"; then
        die "Could not create rollback state file: $STATE_FILE"
    fi
    sudo chmod 0600 "$STATE_FILE"
}

state_b64() {
    printf "%s" "$1" | base64 -w0
}

state_record() {
    local uuid="$1" property="$2" old="$3"
    printf "%s	%s	%s
" "$uuid" "$property" "$(state_b64 "$old")" | sudo tee -a "$STATE_FILE" >/dev/null
}

backup_property() {
    local uuid="$1" property="$2" old
    case "$property" in
        ipv4.dns|ipv6.dns)
            # nmcli prints list-valued properties one item per line. Normalize
            # them to nmcli's comma-separated list syntax before storing them.
            old="$(nmcli -g "$property" connection show "$uuid" 2>/dev/null | awk 'NF' | paste -sd, - || true)"
            ;;
        *)
            old="$(nmcli -g "$property" connection show "$uuid" 2>/dev/null || true)"
            ;;
    esac
    [ "$old" = "--" ] && old=""
    state_record "$uuid" "$property" "$old"
}

state_backup_config() {
    local existed=0 data="" tmp=""
    tmp="$(mktemp)"
    if sudo test -f "$CONFIG_FILE"; then
        existed=1
        if ! sudo base64 -w0 "$CONFIG_FILE" > "$tmp"; then
            rm -f "$tmp"
            die "Could not back up NetworkManager configuration: $CONFIG_FILE"
        fi
        data="$(cat "$tmp")"
    fi

    if ! printf "%s	%s
" "$existed" "$data" | sudo tee "$STATE_DIR/config.tsv.tmp" >/dev/null; then
        rm -f "$tmp"
        die "Could not write NetworkManager configuration rollback state."
    fi
    rm -f "$tmp"

    if ! sudo install -m 0600 "$STATE_DIR/config.tsv.tmp" "$STATE_DIR/config.tsv"; then
        sudo rm -f "$STATE_DIR/config.tsv.tmp"
        die "Could not finalize NetworkManager configuration rollback state."
    fi
    sudo rm -f "$STATE_DIR/config.tsv.tmp"
}

state_exists() {
    sudo test -s "$STATE_FILE"
}
