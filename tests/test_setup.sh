#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$ROOT/setup.sh"
README="$ROOT/README.md"
LICENSE="$ROOT/LICENSE"

bash -n "$SETUP"

grep -q 'wifi.cloned-mac-address=stable-ssid' "$SETUP"
grep -q 'ethernet.cloned-mac-address=stable' "$SETUP"
grep -q '802-11-wireless.cloned-mac-address stable-ssid' "$SETUP"
grep -q '802-3-ethernet.cloned-mac-address stable' "$SETUP"
grep -q 'nmcli general reload conf' "$SETUP"
grep -q '20-arch-privacy-mac.conf' "$SETUP"
grep -q 'macchanger.service' "$SETUP"

if grep -q 'pacman -S macchanger' "$SETUP"; then
    echo "setup.sh must not install macchanger anymore" >&2
    exit 1
fi
if grep -q 'macchanger -r' "$SETUP" || grep -q 'macchanger -s' "$SETUP"; then
    echo "setup.sh must not invoke macchanger anymore" >&2
    exit 1
fi
if grep -q 'systemctl restart NetworkManager' "$SETUP"; then
    echo "setup.sh must not restart NetworkManager" >&2
    exit 1
fi

grep -q 'registration show' "$SETUP"
grep -q 'arch-privacy-warp.lock' "$SETUP"
grep -q 'flock -n 9' "$SETUP"
grep -q 'for _ in $(seq 1 3)' "$SETUP"
grep -q 'warp-cli --accept-tos disconnect' "$SETUP"
grep -q 'warp-network-recover.service' "$SETUP"
grep -q 'systemctl start --no-block warp-autoconnect.service' "$SETUP"
grep -q 'TimeoutStartSec=90' "$SETUP"

if grep -q 'systemctl start warp-autoconnect.service' "$SETUP"; then
    echo "warp-autoconnect must not block setup.sh" >&2
    exit 1
fi

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

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

awk '
  /sudo tee \/usr\/local\/libexec\/arch-privacy-warp-connect > \/dev\/null <<'"'"'EOF'"'"'/ {capture=1; next}
  capture && /^EOF$/ {exit}
  capture {print}
' "$SETUP" > "$tmpdir/arch-privacy-warp-connect"
bash -n "$tmpdir/arch-privacy-warp-connect"

awk '
  /sudo tee \/etc\/NetworkManager\/dispatcher.d\/90-arch-privacy-warp > \/dev\/null <<'"'"'EOF'"'"'/ {capture=1; next}
  capture && /^EOF$/ {exit}
  capture {print}
' "$SETUP" > "$tmpdir/90-arch-privacy-warp"
bash -n "$tmpdir/90-arch-privacy-warp"

echo "Arch Privacy Setup native NetworkManager MAC checks passed."
