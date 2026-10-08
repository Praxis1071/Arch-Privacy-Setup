#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$ROOT/setup.sh"
README="$ROOT/README.md"
ROADMAP="$ROOT/ROADMAP.md"
LICENSE="$ROOT/LICENSE"

bash -n "$SETUP"

grep -q 'Phase 0' "$SETUP"
grep -q 'warp-autoconnect.service' "$SETUP"
grep -q 'warp-network-recover.service' "$SETUP"
grep -q '90-arch-privacy-warp' "$SETUP"
grep -q 'No packages were uninstalled' "$SETUP"

if grep -Eq 'warp-cli.*[[:space:]]connect([[:space:]]|$)' "$SETUP"; then
    echo "Phase 0 cleanup must not connect WARP" >&2
    exit 1
fi

if grep -q 'systemctl restart NetworkManager' "$SETUP"; then
    echo "Cleanup must not restart NetworkManager" >&2
    exit 1
fi

if grep -q 'nft flush ruleset' "$SETUP"; then
    echo "Cleanup must not flush the firewall ruleset" >&2
    exit 1
fi

if grep -q 'pacman -R' "$SETUP" || grep -q 'pacman -Rs' "$SETUP"; then
    echo "Cleanup must not uninstall packages" >&2
    exit 1
fi

grep -q 'Phase 0 — Architecture Cleanup' "$ROADMAP"
grep -q 'Quad9' "$ROADMAP"
grep -q 'MIT License' "$README"
grep -q '^MIT License$' "$LICENSE"

echo "Arch Privacy Setup Phase 0 validation passed."
