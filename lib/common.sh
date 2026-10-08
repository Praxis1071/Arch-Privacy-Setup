#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="/run/lock/arch-privacy-setup.lock"

log(){ printf '[+] %s\n' "$*"; }
warn(){ printf '[!] %s\n' "$*" >&2; }
die(){ printf '[X] %s\n' "$*" >&2; exit 1; }
require_command(){ command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }

acquire_lock() {
    require_command flock
    sudo touch "$LOCK_FILE" || die "Could not create setup lock: $LOCK_FILE"
    sudo chmod 0666 "$LOCK_FILE" || die "Could not prepare setup lock: $LOCK_FILE"
    exec 9<>"$LOCK_FILE"
    flock -n 9 || die "Another Arch Privacy Setup operation is already running."
}
