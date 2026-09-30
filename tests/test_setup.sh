#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$ROOT/setup.sh"
README="$ROOT/README.md"
LICENSE="$ROOT/LICENSE"

bash -n "$SETUP"

grep -q 'registration show' "$SETUP"
grep -q 'arch-privacy-warp.lock' "$SETUP"
grep -q 'flock -n 9' "$SETUP"
grep -q 'for _ in $(seq 1 3)' "$SETUP"
grep -q 'warp-cli --accept-tos disconnect' "$SETUP"
grep -q 'warp-network-recover.service' "$SETUP"

if grep -q '20-connectivity.conf' "$SETUP"; then
    echo "Unexpected mandatory NetworkManager connectivity override remains in setup.sh" >&2
    exit 1
fi

grep -q 'MIT License' "$README"
if grep -qi 'GNU General Public License' "$README"; then
    echo "README still contains the old GPL license statement" >&2
    exit 1
fi

grep -q '^MIT License$' "$LICENSE"

echo "Arch Privacy Setup static checks passed."
