#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")/.." && pwd)"

bash -n "$ROOT/setup.sh" "$ROOT/rollback.sh" "$ROOT/audit.sh" "$ROOT/lib/common.sh" "$ROOT/lib/state.sh" "$ROOT/lib/mac.sh" "$ROOT/lib/privacy.sh"

grep -q "802-11-wireless.cloned-mac-address random" "$ROOT/lib/mac.sh"
grep -q "802-3-ethernet.cloned-mac-address random" "$ROOT/lib/mac.sh"
grep -q "backup_property" "$ROOT/lib/mac.sh"
grep -q "wifi.scan-rand-mac-address=yes" "$ROOT/lib/privacy.sh"
grep -q "connection.dns-over-tls yes" "$ROOT/lib/privacy.sh"
grep -q "connection.dnssec yes" "$ROOT/lib/privacy.sh"
grep -q "ipv4.dhcp-client-id stable" "$ROOT/lib/privacy.sh"
grep -q "ipv6.addr-gen-mode stable-privacy" "$ROOT/lib/privacy.sh"
grep -q "ipv6.ip6-privacy prefer-temp-addr" "$ROOT/lib/privacy.sh"
grep -q "connection.llmnr no" "$ROOT/lib/privacy.sh"
grep -q "connection.mdns no" "$ROOT/lib/privacy.sh"
grep -q "9.9.9.9#dns.quad9.net" "$ROOT/lib/privacy.sh"
grep -q "2620:fe::fe#dns.quad9.net" "$ROOT/lib/privacy.sh"
grep -q "No Arch Privacy Setup rollback state" "$ROOT/rollback.sh"
grep -q "State was preserved for another rollback attempt" "$ROOT/rollback.sh"
grep -q "An existing rollback state was found" "$ROOT/setup.sh"
grep -q "does not prove end-to-end DNS privacy" "$ROOT/audit.sh"

if grep -REq "macchanger|nft flush ruleset|systemctl restart NetworkManager" "$ROOT/setup.sh" "$ROOT/rollback.sh" "$ROOT/audit.sh" "$ROOT/lib/"*.sh; then
    exit 1
fi

echo "Static validation passed."
