#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
source "$ROOT/lib/common.sh"

require_command nmcli
require_command systemctl
require_command ip
require_command awk
require_command grep

pass=0
config_warns=0
live_warns=0

check_config() {
    local label="$1" result="$2"
    if [ "$result" = "ok" ]; then
        printf "[PASS] %s\n" "$label"
        pass=$((pass+1))
    else
        printf "[WARN] %s\n" "$label"
        config_warns=$((config_warns+1))
    fi
}

check_live() {
    local label="$1" result="$2"
    if [ "$result" = "ok" ]; then
        printf "[PASS] %s\n" "$label"
        pass=$((pass+1))
    else
        printf "[WARN] %s\n" "$label"
        live_warns=$((live_warns+1))
    fi
}

CONFIG="/etc/NetworkManager/conf.d/90-arch-privacy-setup.conf"

if systemctl is-active --quiet systemd-resolved; then
    check_config "systemd-resolved active" ok
else
    check_config "systemd-resolved active" warn
fi

if [ -f "$CONFIG" ] &&
   grep -q "^dns=systemd-resolved$" "$CONFIG"; then
    check_config "NetworkManager uses systemd-resolved DNS backend" ok
else
    check_config "NetworkManager uses systemd-resolved DNS backend" warn
fi

if [ -f "$CONFIG" ] &&
   grep -q "^wifi.scan-rand-mac-address=yes$" "$CONFIG"; then
    check_config "Wi-Fi scan MAC randomization configured" ok
else
    check_config "Wi-Fi scan MAC randomization configured" warn
fi

for expected in     "llmnr=no"     "mdns=no"     "dns-over-tls=yes"     "dnssec=yes"     "ipv4.dhcp-client-id=stable"     "ipv4.dhcp-iaid=stable"     "ipv4.dhcp-send-hostname=no"     "ipv6.addr-gen-mode=stable-privacy"     "ipv6.ip6-privacy=2"     "ipv6.dhcp-duid=stable-uuid"     "ipv6.dhcp-iaid=stable"     "ipv6.dhcp-send-hostname=no"     "wifi.cloned-mac-address=random"     "ethernet.cloned-mac-address=random"; do
    if [ -f "$CONFIG" ] && grep -q "^$expected$" "$CONFIG"; then
        check_config "Global default $expected" ok
    else
        check_config "Global default $expected" warn
    fi
done

while IFS=: read -r uuid type; do
    [ -n "$uuid" ] || continue
    case "$type" in
        802-11-wireless)
            mac="$(nmcli -g 802-11-wireless.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
            device="$(nmcli -g GENERAL.DEVICES connection show "$uuid" 2>/dev/null || true)"
            ;;
        802-3-ethernet)
            mac="$(nmcli -g 802-3-ethernet.cloned-mac-address connection show "$uuid" 2>/dev/null || true)"
            device="$(nmcli -g GENERAL.DEVICES connection show "$uuid" 2>/dev/null || true)"
            ;;
        *) continue ;;
    esac

    check_config "$type profile $uuid randomized MAC configured" "$([ "$mac" = "random" ] && echo ok || echo warn)"

    dot="$(nmcli -g connection.dns-over-tls connection show "$uuid" 2>/dev/null || true)"
    dnssec="$(nmcli -g connection.dnssec connection show "$uuid" 2>/dev/null || true)"
    llmnr="$(nmcli -g connection.llmnr connection show "$uuid" 2>/dev/null || true)"
    mdns="$(nmcli -g connection.mdns connection show "$uuid" 2>/dev/null || true)"
    dhcpid="$(nmcli -g ipv4.dhcp-client-id connection show "$uuid" 2>/dev/null || true)"
    dhcpiaid="$(nmcli -g ipv4.dhcp-iaid connection show "$uuid" 2>/dev/null || true)"
    dhcphost4="$(nmcli -g ipv4.dhcp-send-hostname-v2 connection show "$uuid" 2>/dev/null || true)"
    ipv6gen="$(nmcli -g ipv6.addr-gen-mode connection show "$uuid" 2>/dev/null || true)"
    ipv6priv="$(nmcli -g ipv6.ip6-privacy connection show "$uuid" 2>/dev/null || true)"
    duid="$(nmcli -g ipv6.dhcp-duid connection show "$uuid" 2>/dev/null || true)"
    ipv6iaid="$(nmcli -g ipv6.dhcp-iaid connection show "$uuid" 2>/dev/null || true)"
    dhcphost6="$(nmcli -g ipv6.dhcp-send-hostname-v2 connection show "$uuid" 2>/dev/null || true)"
    ignore4="$(nmcli -g ipv4.ignore-auto-dns connection show "$uuid" 2>/dev/null || true)"
    ignore6="$(nmcli -g ipv6.ignore-auto-dns connection show "$uuid" 2>/dev/null || true)"
    dns4="$(nmcli -g ipv4.dns connection show "$uuid" 2>/dev/null || true)"
    dns6="$(nmcli -g ipv6.dns connection show "$uuid" 2>/dev/null || true)"

    [ "$dot" = "yes" ] && check_config "$uuid DNS-over-TLS configured" ok || check_config "$uuid DNS-over-TLS configured" warn
    [ "$dnssec" = "yes" ] && check_config "$uuid DNSSEC configured" ok || check_config "$uuid DNSSEC configured" warn
    [ "$llmnr" = "no" ] && check_config "$uuid LLMNR disabled" ok || check_config "$uuid LLMNR disabled" warn
    [ "$mdns" = "no" ] && check_config "$uuid mDNS disabled" ok || check_config "$uuid mDNS disabled" warn
    [ "$dhcpid" = "stable" ] && check_config "$uuid DHCPv4 stable client ID" ok || check_config "$uuid DHCPv4 stable client ID" warn
    [ "$dhcpiaid" = "stable" ] && check_config "$uuid DHCPv4 stable IAID" ok || check_config "$uuid DHCPv4 stable IAID" warn
    [ "$dhcphost4" = "no" ] && check_config "$uuid DHCPv4 hostname disabled" ok || check_config "$uuid DHCPv4 hostname disabled" warn
    [ "$ipv6gen" = "stable-privacy" ] && check_config "$uuid IPv6 stable privacy addressing" ok || check_config "$uuid IPv6 stable privacy addressing" warn
    case "$ipv6priv" in prefer-temp-addr|2) check_config "$uuid IPv6 temporary addresses preferred" ok ;; *) check_config "$uuid IPv6 temporary addresses preferred" warn ;; esac
    [ "$duid" = "stable-uuid" ] && check_config "$uuid DHCPv6 stable DUID" ok || check_config "$uuid DHCPv6 stable DUID" warn
    [ "$ipv6iaid" = "stable" ] && check_config "$uuid DHCPv6 stable IAID" ok || check_config "$uuid DHCPv6 stable IAID" warn
    [ "$dhcphost6" = "no" ] && check_config "$uuid DHCPv6 hostname disabled" ok || check_config "$uuid DHCPv6 hostname disabled" warn
    [ "$ignore4" = "yes" ] && check_config "$uuid DHCPv4 DNS ignored" ok || check_config "$uuid DHCPv4 DNS ignored" warn
    [ "$ignore6" = "yes" ] && check_config "$uuid DHCPv6 DNS ignored" ok || check_config "$uuid DHCPv6 DNS ignored" warn

    if printf '%s\n' "$dns4" | grep -Fxq "9.9.9.9#dns.quad9.net" &&
       printf '%s\n' "$dns4" | grep -Fxq "149.112.112.112#dns.quad9.net"; then
        check_config "$uuid Quad9 IPv4 DNS configured" ok
    else
        check_config "$uuid Quad9 IPv4 DNS configured" warn
    fi

    if printf '%s\n' "$dns6" | grep -Fxq "2620:fe::fe#dns.quad9.net" &&
       printf '%s\n' "$dns6" | grep -Fxq "2620:fe::9#dns.quad9.net"; then
        check_config "$uuid Quad9 IPv6 DNS configured" ok
    else
        check_config "$uuid Quad9 IPv6 DNS configured" warn
    fi

    if [ -n "$device" ] && [ "$device" != "--" ]; then
        device="${device%%,*}"
        actual_mac="$(nmcli -g GENERAL.HWADDR device show "$device" 2>/dev/null || true)"
        permanent_mac="$(nmcli -g GENERAL.PERMANENT-HWADDR device show "$device" 2>/dev/null || true)"

        if [ -n "$actual_mac" ] && [ -n "$permanent_mac" ] && [ "$actual_mac" != "$permanent_mac" ]; then
            first_octet="${actual_mac%%:*}"
            first_octet_dec=$((16#${first_octet}))
            if (( (first_octet_dec & 2) != 0 && (first_octet_dec & 1) == 0 )); then
                check_live "$uuid active MAC differs from permanent MAC and is locally administered" ok
            else
                check_live "$uuid active MAC differs but does not have expected randomized MAC flags" warn
            fi
        else
            check_live "$uuid active MAC randomization not yet observable (reconnect may be required)" warn
        fi
    fi
done < <(nmcli -t -f UUID,TYPE connection show)

printf "\nAudit summary: %d passed, %d configuration warnings, %d live-state warnings.\n" "$pass" "$config_warns" "$live_warns"
printf "PASS means configuration/live-state evidence was observed. Live-state warnings do not fail setup because active connections are intentionally not forcibly restarted.\n"
printf "This audit does not prove end-to-end DNS privacy, packet-level DHCP identity behavior, or network compatibility.\n"

[ "$config_warns" -eq 0 ]
