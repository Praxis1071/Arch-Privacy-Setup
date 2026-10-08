#!/usr/bin/env bash
set -euo pipefail

configure_mac_profiles() {
    local uuid type cloned
    while IFS=: read -r uuid type; do
        [ -n "$uuid" ] || continue
        case "$type" in
            802-11-wireless)
                cloned="$(nmcli -g 802-11-wireless.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
                if [ -z "$cloned" ] || [ "$cloned" = "--" ]; then
                    backup_property "$uuid" 802-11-wireless.cloned-mac-address
                    sudo nmcli connection modify "$uuid" 802-11-wireless.cloned-mac-address random
                fi
                ;;
            802-3-ethernet)
                cloned="$(nmcli -g 802-3-ethernet.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
                if [ -z "$cloned" ] || [ "$cloned" = "--" ]; then
                    backup_property "$uuid" 802-3-ethernet.cloned-mac-address
                    sudo nmcli connection modify "$uuid" 802-3-ethernet.cloned-mac-address random
                fi
                ;;
        esac
    done < <(nmcli -t -f UUID,TYPE connection show)
}
