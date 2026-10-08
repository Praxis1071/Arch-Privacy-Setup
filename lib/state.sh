#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/var/lib/arch-privacy-setup"
STATE_FILE="$STATE_DIR/state.tsv"
CONFIG_FILE="/etc/NetworkManager/conf.d/90-arch-privacy-setup.conf"

state_init() {
    sudo install -d -m 0700 "$STATE_DIR"
    sudo touch "$STATE_FILE"
    sudo chmod 0600 "$STATE_FILE"
}

state_b64() {
    printf "%s" "$1" | base64 -w0
}

state_record() {
    local uuid="$1" property="$2" old="$3"
    printf "%s\t%s\t%s\n" "$uuid" "$property" "$(state_b64 "$old")" | sudo tee -a "$STATE_FILE" >/dev/null
}

backup_property() {
    local uuid="$1" property="$2" old
    old="$(nmcli -g "$property" connection show "$uuid" 2>/dev/null || true)"
    [ "$old" = "--" ] && old=""
    state_record "$uuid" "$property" "$old"
}

state_backup_config() {
    local existed=0 data=""
    if sudo test -f "$CONFIG_FILE"; then
        existed=1
        data="$(sudo base64 -w0 "$CONFIG_FILE")"
    fi
    printf "%s\t%s\n" "$existed" "$data" | sudo tee "$STATE_DIR/config.tsv" >/dev/null
    sudo chmod 0600 "$STATE_DIR/config.tsv"
}

state_exists() {
    sudo test -s "$STATE_FILE"
}
