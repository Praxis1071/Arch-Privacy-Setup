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
- [x] Reboot/reconnect behavior implemented.
- [ ] Real reboot validation.
- [ ] Real reconnect validation.
- [ ] Android hotspot validation.
- [ ] Home/router Wi-Fi validation.
- [ ] Suspend/resume validation.
- [ ] DHCP/IPv4 validation.

## Phase 2 — Wi-Fi Scan Privacy
- [x] Verify current NetworkManager scan-randomization mechanism.
- [x] Enable scan randomization explicitly.
- [ ] Real hardware verification.

## Phase 3 — Encrypted DNS
- [x] Quad9.
- [x] DNS-over-TLS.
- [x] DNSSEC.
- [x] IPv4/IPv6 DNS configuration.
- [ ] Live DNS leak verification.

## Phase 4 — DHCP Identity Privacy
- [x] Stable IPv4 DHCP client ID.
- [x] Stable IPv4 IAID.
- [x] Stable IPv6 DUID.
- [x] Stable IPv6 IAID.
- [x] Disable DHCP hostname transmission.
- [ ] Packet-level validation.

## Phase 5 — IPv6 Privacy
- [x] RFC7217 stable-privacy addressing.
- [x] RFC4941 temporary addresses preferred.
- [x] Keep IPv6 enabled.
- [ ] Live IPv6 validation.

## Phase 6 — Local Network Privacy
- [x] Disable LLMNR.
- [x] Disable mDNS.
- [x] Preserve rollback values.
- [ ] Compatibility validation for local discovery workflows.

## Phase 7 — Read-only Privacy Audit
- [x] Add read-only `audit.sh`.
- [x] Verify configured privacy properties without changing them.

## Phase 8 — Recovery / Rollback
- [x] Backup managed connection properties before modification.
- [x] Backup project-owned NetworkManager config.
- [x] Automatic rollback on setup failure.
- [x] Manual offline rollback command.
- [x] Refuse to overwrite an existing rollback state.

## Phase 9 — Real Hardware Test Suite
- [x] Static validation.
- [x] Read-only live audit.
- [ ] User hardware validation: reboot.
- [ ] User hardware validation: reconnect.
- [ ] User hardware validation: Android hotspot.
- [ ] User hardware validation: home/router Wi-Fi.
- [ ] User hardware validation: suspend/resume.
- [ ] User hardware validation: IPv4/IPv6/DNS.

## Phase 10 — Release Audit
- [x] No WARP architecture.
- [x] No custom MAC daemon.
- [x] No global nftables flush.
- [x] No forced NetworkManager restart.
- [x] Rollback documentation.
- [ ] Final real-hardware release sign-off.

## Definition of done

A phase is complete only after configuration correctness, live-state verification, normal networking, privacy behavior, failure detection, and safe reversal are demonstrated.
