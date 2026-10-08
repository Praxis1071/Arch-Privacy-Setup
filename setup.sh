#!/usr/bin/env bash
#
# Arch Privacy Setup
# Phase 0: remove components belonging to the previous WARP architecture.
#
# This migration intentionally does NOT install new privacy features.
# New features are added phase-by-phase after implementation and verification.
#
set -uo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    echo "[X] Run this script as a normal user; it will request sudo when needed." >&2
    exit 1
fi

log()  { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[X] %s\n' "$*" >&2; exit 1; }

command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v systemctl >/dev/null 2>&1 || die "systemd is required."

log "Removing the previous Arch Privacy Setup WARP architecture..."

if command -v warp-cli >/dev/null 2>&1; then
    warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
fi

sudo systemctl disable --now warp-autoconnect.service >/dev/null 2>&1 || true
sudo systemctl disable --now warp-network-recover.service >/dev/null 2>&1 || true

sudo rm -f \
    /etc/systemd/system/warp-autoconnect.service \
    /etc/systemd/system/warp-network-recover.service \
    /usr/local/libexec/arch-privacy-warp-connect \
    /etc/NetworkManager/dispatcher.d/90-arch-privacy-warp

sudo rm -f \
    /etc/NetworkManager/conf.d/20-arch-privacy-mac.conf \
    /etc/NetworkManager/conf.d/10-mac-preserve.conf \
    /etc/systemd/system/macchanger.service

sudo systemctl daemon-reload

if command -v nmcli >/dev/null 2>&1; then
    sudo nmcli general reload conf >/dev/null 2>&1 || \
        warn "NetworkManager configuration reload failed; no daemon restart was attempted."
fi

log "Legacy WARP components removed."
log "No packages were uninstalled."
log "No new privacy configuration was applied."
log "Phase 0 cleanup is complete."
log "Next implementation phase: NetworkManager-native MAC privacy."
