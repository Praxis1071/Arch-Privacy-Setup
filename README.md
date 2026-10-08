# Arch Privacy Setup

A conservative privacy-hardening project for Arch Linux and Arch-based systems such as CachyOS.

The project is being rebuilt around one priority:

> **Improve practical network privacy without sacrificing network stability.**

The new architecture deliberately avoids Cloudflare WARP, custom MAC-changing daemons, and broad firewall resets. NetworkManager and systemd will be preferred wherever they provide a native, reliable mechanism.

## Current status

**Phase 1 — MAC Privacy** is implemented; hardware validation is still pending.

The project now uses NetworkManager-native MAC randomization. It works at the connection-profile level, so the same mechanism applies to home/router Wi-Fi and phone hotspots. It does not forcibly restart active connections.

This is intentional: no privacy feature is enabled until it has its own implementation and verification tests.

## Current MAC behavior

NetworkManager's `random` policy generates a randomized MAC when a connection is activated. This is intentionally different from a custom "change once at boot" daemon. Reboot, reconnect, suspend/resume, hotspot, and DHCP behavior must be validated on real hardware before those guarantees are claimed.

## New architecture

Planned components:

```text
setup.sh
├── lib/
│   ├── common.sh
│   ├── cleanup.sh
│   └── ...
├── config/
│   └── ...
├── tests/
│   └── ...
└── docs/
    └── ARCHITECTURE.md
```

The implementation will follow:

**Detect → Apply → Verify → Roll back on failure**

No feature should be considered complete merely because a configuration file was written. It must also be checked against the live system.

## Privacy roadmap

See [ROADMAP.md](ROADMAP.md).

The approved direction is:

1. Remove the old WARP architecture.
2. Implement NetworkManager-native MAC randomization.
3. Enable Wi-Fi scan MAC randomization where appropriate.
4. Implement encrypted DNS using Quad9.
5. Review DHCP identity and hostname exposure.
6. Review IPv6 privacy without disabling IPv6.
7. Review LLMNR/mDNS exposure with compatibility safeguards.
8. Add a read-only privacy audit.
9. Add safe apply/verification/rollback behavior.
10. Test on real Arch/CachyOS hardware and common Wi-Fi/hotspot scenarios.

### DNS note

The project will use **Quad9** rather than building the new design around Mullvad's public DNS service. This avoids depending on a public DNS service that is being retired.

## Safety principles

- Do not globally flush nftables.
- Do not restart NetworkManager unnecessarily.
- Do not replace NetworkManager with a custom network manager.
- Do not use `macchanger` as a boot-time service.
- Do not silently uninstall packages the user may need elsewhere.
- Do not claim privacy improvements that have not been verified.
- Preserve user-managed network profiles where possible.
- Prefer reversible configuration changes.

## License

MIT License. See [LICENSE](LICENSE).
