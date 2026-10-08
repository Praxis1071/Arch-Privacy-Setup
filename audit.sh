#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
source "$ROOT/lib/common.sh"

require_command nmcli
require_command systemctl

pass=0
warns=0

check() {
    local label="$1" result="$2"
    if [ "$result" = "ok" ]; then
        printf "[PASS] %s\n" "$label"
        pass=$((pass+1))
    else
        printf "[WARN] %s\n" "$label"
        warns=$((warns+1))
    fi
}

if systemctl is-active --quiet systemd-resolved; then
    check "systemd-resolved active" ok
else
    check "systemd-resolved active" warn
fi

if [ -f /etc/NetworkManager/conf.d/90-arch-privacy-setup.conf ] &&
   grep -q "^wifi.scan-rand-mac-address=yes$" /etc/NetworkManager/conf.d/90-arch-privacy-setup.conf; then
    check "Wi-Fi scan MAC randomization configured" ok
else
    check "Wi-Fi scan MAC randomization configured" warn
fi

while IFS=: read -r uuid type; do
    [ -n "$uuid" ] || continue
    case "$type" in
        802-11-wireless)
            mac="$(nmcli -g 802-11-wireless.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
            ;;
        802-3-ethernet)
            mac="$(nmcli -g 802-3-ethernet.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
            ;;
        *) continue ;;
    esac
    [ "$mac" = "random" ] && check "$type profile $uuid randomized MAC" ok || check "$type profile $uuid randomized MAC" warn

    dot="$(nmcli -g connection.dns-over-tls connection show "$uuid" 2>/dev/null || true)"
    dnssec="$(nmcli -g connection.dnssec connection show "$uuid" 2>/dev/null || true)"
    llmnr="$(nmcli -g connection.llmnr connection show "$uuid" 2>/dev/null || true)"
    mdns="$(nmcli -g connection.mdns connection show "$uuid" 2>/dev/null || true)"
    dhcpid="$(nmcli -g ipv4.dhcp-client-id connection show "$uuid" 2>/dev/null || true)"
    ipv6gen="$(nmcli -g ipv6.addr-gen-mode connection show "$uuid" 2>/dev/null || true)"
    ipv6priv="$(nmcli -g ipv6.ip6-privacy connection show "$uuid" 2>/dev/null || true)"

    [ "$dot" = "yes" ] && check "$uuid DNS-over-TLS" ok || check "$uuid DNS-over-TLS" warn
    [ "$dnssec" = "yes" ] && check "$uuid DNSSEC" ok || check "$uuid DNSSEC" warn
    [ "$llmnr" = "no" ] && check "$uuid LLMNR disabled" ok || check "$uuid LLMNR disabled" warn
    [ "$mdns" = "no" ] && check "$uuid mDNS disabled" ok || check "$uuid mDNS disabled" warn
    [ "$dhcpid" = "stable" ] && check "$uuid DHCPv4 stable client ID" ok || check "$uuid DHCPv4 stable client ID" warn
    [ "$ipv6gen" = "stable-privacy" ] && check "$uuid IPv6 stable privacy addressing" ok || check "$uuid IPv6 stable privacy addressing" warn
    case "$ipv6priv" in prefer-temp-addr|2) check "$uuid IPv6 temporary addresses preferred" ok ;; *) check "$uuid IPv6 temporary addresses preferred" warn ;; esac
done < <(nmcli -t -f UUID,TYPE connection show)

printf "\nAudit summary: %d passed, %d warnings.\n" "$pass" "$warns"
