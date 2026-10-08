# Arch Privacy Setup Roadmap

## Phase 0 — Architecture Cleanup
- [x] Remove Cloudflare WARP architecture.
- [x] Establish new project structure.

## Phase 1 — MAC Privacy
- [x] NetworkManager-native random MAC.
- [x] Wi-Fi profiles.
- [x] Ethernet profiles.
- [x] Preserve explicit user MAC policies.
- [x] Avoid custom MAC-changing daemons.
- [ ] Reboot validation.
- [ ] Reconnect validation.
- [ ] Android hotspot validation.
- [ ] Home/router Wi-Fi validation.
- [ ] Suspend/resume validation.
- [ ] DHCP/IPv4 validation.

## Phase 2 — Wi-Fi Scan Privacy
- [ ] Verify NetworkManager scan randomization.
- [ ] Enable/retain only where compatible.

## Phase 3 — Encrypted DNS
- [ ] Quad9.
- [ ] DNS-over-TLS.
- [ ] IPv4/IPv6 and leak verification.

## Later phases
- [ ] DHCP identity hardening.
- [ ] IPv6 privacy.
- [ ] LLMNR/mDNS review.
- [ ] Read-only audit.
- [ ] Backup/verification/rollback.
- [ ] Real hardware test suite.
- [ ] Release audit.

## Definition of done
A phase is complete only after configuration correctness, live-state verification, normal networking, privacy behavior, failure detection, and safe reversal are demonstrated.
