#!/usr/bin/env bash
set -euo pipefail
log(){ printf '[+] %s\n' "$*"; }
warn(){ printf '[!] %s\n' "$*" >&2; }
die(){ printf '[X] %s\n' "$*" >&2; exit 1; }
require_command(){ command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
