# Arch Privacy Setup Roadmap

## Project goal

Build a practical privacy-hardening setup for Arch Linux and Arch-based systems that produces measurable privacy improvements while keeping normal networking reliable.

The project must prefer stability over unnecessary complexity.

## Architecture principles

1. **Native first** — prefer NetworkManager, systemd, systemd-resolved and kernel-supported mechanisms.
2. **No unnecessary daemons** — do not recreate functionality that the base system already provides reliably.
3. **Apply → Verify → Rollback** — every state-changing feature needs verification and a recovery path.
4. **Least destructive** — never flush unrelated firewall state or overwrite explicit user configuration without a clear reason.
5. **Evidence-based privacy** — every feature must have a concrete privacy rationale and a testable result.
6. **Real hardware validation** — CI is not enough for networking changes.

## Phases

### Phase 0 — Architecture Cleanup
- [x] Remove Cloudflare WARP integration.
- [x] Remove WARP systemd units and NetworkManager dispatcher.
- [x] Remove WARP-specific helper logic.
- [x] Remove the old WARP/MAC architecture from documentation and tests.
- [x] Keep the MIT license.
- [x] Establish the new project structure.

### Phase 1 — MAC Privacy
- [ ] Use NetworkManager-native random MAC addressing.
- [ ] Define Wi-Fi activation behavior.
- [ ] Define Ethernet behavior.
- [ ] Verify reboot and reconnect behavior.
- [ ] Verify Android hotspot behavior.
- [ ] Verify suspend/resume.
- [ ] Preserve explicit user MAC policies.

### Phase 2 — Wi-Fi Scan Privacy
- [ ] Review NetworkManager scan MAC randomization.
- [ ] Enable it only when compatible with normal Wi-Fi discovery.
- [ ] Verify live scan behavior.

### Phase 3 — Encrypted DNS
- [ ] Use Quad9.
- [ ] Prefer DNS-over-TLS through the system resolver architecture.
- [ ] Verify IPv4 DNS resolution.
- [ ] Verify IPv6 DNS resolution.
- [ ] Verify DNS leak behavior.
- [ ] Define a safe fallback so DNS hardening cannot strand the system without name resolution.

### Phase 4 — DHCP Privacy
- [ ] Review DHCP hostname exposure.
- [ ] Review DHCP client identity behavior.
- [ ] Reduce unnecessary identifying information without breaking networks.

### Phase 5 — IPv6 Privacy
- [ ] Keep IPv6 enabled.
- [ ] Use privacy addresses where supported.
- [ ] Verify IPv6 connectivity.
- [ ] Verify that DNS and routing remain functional.

### Phase 6 — Local Network Privacy
- [ ] Review LLMNR.
- [ ] Review mDNS.
- [ ] Disable only where the privacy benefit outweighs compatibility impact.
- [ ] Document exceptions.

### Phase 7 — Privacy Audit
- [ ] Add a read-only `--audit` mode.
- [ ] Report MAC policy and live MAC state.
- [ ] Report DNS configuration and resolver state.
- [ ] Report IPv6 privacy state.
- [ ] Report local-name-resolution settings.
- [ ] Never present an arbitrary numerical "privacy score" as scientific evidence.

### Phase 8 — Recovery
- [ ] Back up managed configuration.
- [ ] Verify connectivity after changes.
- [ ] Automatically restore the previous configuration when verification fails.
- [ ] Make rollback independently usable.

### Phase 9 — Real Hardware Testing
- [ ] CachyOS.
- [ ] ThinkPad X13 Gen 1.
- [ ] Intel AX201.
- [ ] Android hotspot.
- [ ] Wi-Fi reconnect.
- [ ] Reboot.
- [ ] Suspend/resume.
- [ ] IPv4.
- [ ] IPv6.
- [ ] DNS failure scenarios.

### Phase 10 — Documentation & Release
- [ ] Document supported systems.
- [ ] Document every managed setting.
- [ ] Document troubleshooting and rollback.
- [ ] Add reproducible test procedures.
- [ ] Perform final architecture and security audit.
- [ ] Publish a stable release.

## Definition of done

A phase is not complete because the script runs without errors.

A phase is complete only when:

- the configuration is correct,
- the live system reflects the intended state,
- ordinary networking still works,
- the privacy property can be demonstrated,
- failure can be detected,
- and the change can be reversed safely.
