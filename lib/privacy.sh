#!/usr/bin/env bash
set -euo pipefail

PRIVACY_PROPERTIES=(
    "connection.llmnr"
    "connection.mdns"
    "connection.dns-over-tls"
    "connection.dnssec"
    "ipv4.dhcp-client-id"
    "ipv4.dhcp-iaid"
    "ipv4.dhcp-send-hostname-v2"
    "ipv4.dns"
    "ipv4.ignore-auto-dns"
    "ipv6.addr-gen-mode"
    "ipv6.ip6-privacy"
    "ipv6.dhcp-duid"
    "ipv6.dhcp-iaid"
    "ipv6.dhcp-send-hostname-v2"
    "ipv6.dns"
    "ipv6.ignore-auto-dns"
)

configure_scan_privacy() {
    local file="/etc/NetworkManager/conf.d/90-arch-privacy-setup.conf"
    sudo install -d -m 0755 /etc/NetworkManager/conf.d
    sudo tee "$file" >/dev/null <<'CONF'
# Managed by Arch Privacy Setup.
[device]
wifi.scan-rand-mac-address=yes
CONF
    sudo chmod 0644 "$file"
}

configure_connection_privacy() {
    local uuid type property
    while IFS=: read -r uuid type; do
        [ -n "$uuid" ] || continue
        case "$type" in
            802-11-wireless|802-3-ethernet)
                for property in "${PRIVACY_PROPERTIES[@]}"; do
                    backup_property "$uuid" "$property"
                done
                sudo nmcli connection modify "$uuid" \
                    connection.llmnr no \
                    connection.mdns no \
                    connection.dns-over-tls yes \
                    connection.dnssec yes \
                    ipv4.dhcp-client-id stable \
                    ipv4.dhcp-iaid stable \
                    ipv4.dhcp-send-hostname-v2 no \
                    ipv4.dns "9.9.9.9#dns.quad9.net,149.112.112.112#dns.quad9.net" \
                    ipv4.ignore-auto-dns yes \
                    ipv6.addr-gen-mode stable-privacy \
                    ipv6.ip6-privacy prefer-temp-addr \
                    ipv6.dhcp-duid stable-uuid \
                    ipv6.dhcp-iaid stable \
                    ipv6.dhcp-send-hostname-v2 no \
                    ipv6.dns "2620:fe::fe#dns.quad9.net,2620:fe::9#dns.quad9.net" \
                    ipv6.ignore-auto-dns yes
                ;;
        esac
    done < <(nmcli -t -f UUID,TYPE connection show)
}
