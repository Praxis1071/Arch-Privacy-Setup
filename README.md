# Arch Privacy Setup

A conservative privacy-hardening project for Arch Linux and Arch-based systems such as CachyOS.

The goal is practical network privacy without turning networking into a fragile stack.

## Current implementation

The complete planned privacy-hardening implementation is now present in the repository:

- NetworkManager-native randomized MAC addresses.
- Randomized MAC during Wi-Fi scanning.
- Quad9 DNS with DNS-over-TLS.
- DNSSEC.
- DHCP identity hardening.
- IPv6 stable-privacy and temporary-address preference.
- LLMNR and mDNS disabled on managed Wi-Fi/Ethernet profiles.
- Read-only audit.
- Automatic and manual rollback.

**Real hardware validation is intentionally still separate.** The implementation is in place, but reboot, reconnect, Android hotspot, home/router Wi-Fi, suspend/resume, IPv4/IPv6 and DNS behavior must be validated on actual hardware before final release sign-off.

## Requirements

- Arch Linux or an Arch-based distribution.
- NetworkManager.
- systemd-resolved active.
- sudo.
- nmcli.
- base64, tac and flock.

The project does not install or replace a network manager.

## Apply

Clone the repository and run:

```bash
cd Arch-Privacy-Setup
chmod +x setup.sh rollback.sh audit.sh
./setup.sh
```

The setup:

1. Checks prerequisites before changing anything.
2. Refuses to overwrite an existing rollback state.
3. Backs up every NetworkManager property it changes.
4. Backs up its project-owned NetworkManager configuration.
5. Applies all implemented privacy layers.
6. Reloads NetworkManager configuration without forcibly restarting NetworkManager.
7. Runs a read-only audit.
8. Automatically attempts rollback if setup fails.

**Keep the terminal open until the audit finishes.**

The setup does not forcibly disconnect an active connection. Some connection-activation settings take full effect after reconnect or reboot. NetworkManager's systemd-resolved DNS backend is selected explicitly so the per-connection DoT/DNSSEC settings have a compatible backend.

## Implemented privacy layers

### MAC privacy

- Wi-Fi profiles: `cloned-mac-address=random`.
- Ethernet profiles: `cloned-mac-address=random`.
- Existing explicit MAC policies are preserved.

### Wi-Fi scan privacy

NetworkManager scan randomization is explicitly enabled.

### Quad9 encrypted DNS

Managed Wi-Fi/Ethernet profiles use:

- IPv4: `9.9.9.9`, `149.112.112.112`
- IPv6: `2620:fe::fe`, `2620:fe::9`
- TLS server name: `dns.quad9.net`
- DNS-over-TLS: required.
- DNSSEC: required.
- DHCP-provided DNS: ignored.

The NetworkManager systemd-resolved DNS backend is selected explicitly. This is required because NetworkManager's per-connection DNS-over-TLS setting only has an effect with a compatible DNS plugin such as `systemd-resolved`. The project still requires live packet-level testing to prove that queries actually leave through TCP/853.

### Defaults for newly created profiles

NetworkManager global connection defaults are also configured for MAC randomization, DoT, DNSSEC, LLMNR/mDNS, DHCP identity and IPv6 privacy. Explicit settings already present on a profile remain authoritative.

The project cannot safely force Quad9 addresses as a global DNS override because doing so would interfere with VPN/split-DNS and other connection-specific DNS routing. Therefore newly created profiles inherit the privacy defaults, while the complete Quad9 server list is applied to the profiles present when setup runs.

### DHCP privacy

Managed profiles use stable NetworkManager DHCP identifiers rather than identifiers derived directly from the permanent hardware MAC. DHCP hostname transmission is disabled.

### IPv6 privacy

IPv6 is **not disabled**.

The project uses NetworkManager stable-privacy address generation and prefers temporary IPv6 addresses.

### Local-network privacy

LLMNR and mDNS are disabled for managed Wi-Fi/Ethernet profiles.

This can affect:

- `.local` name resolution.
- Network printer discovery.
- AirPrint/Chromecast-style discovery.
- Some LAN service discovery.

If those features are needed, use rollback instead of manually editing profiles.

## Audit

Run the read-only audit at any time:

```bash
./audit.sh
```

It does not modify NetworkManager or firewall state.

## IMPORTANT: emergency rollback

If networking stops working, DNS fails, Wi-Fi cannot reconnect, IPv6 causes problems, or local discovery is needed again:

```bash
./rollback.sh
```

Rollback is designed to work **without internet access** because it restores local NetworkManager state from `/var/lib/arch-privacy-setup/`. It verifies each restored property before deleting the rollback state:

```
/var/lib/arch-privacy-setup/
```

After rollback, reconnect the affected network if necessary.

If setup itself encounters an error, it automatically attempts the same rollback.

### What rollback restores

- Previous Wi-Fi MAC policy.
- Previous Ethernet MAC policy.
- Previous DNS servers and automatic-DNS behavior.
- Previous DNS-over-TLS and DNSSEC values.
- Previous DHCP client ID, IAID, DUID and hostname settings.
- Previous IPv6 address/privacy settings.
- Previous LLMNR/mDNS settings.
- Previous project-owned NetworkManager scan configuration.

If any restore or verification step fails, rollback exits non-zero and **preserves the state directory** so it can be retried.

It does **not**:

- uninstall NetworkManager;
- uninstall system packages;
- remove unrelated connection profiles;
- flush nftables;
- forcibly restart NetworkManager.

## Safety model

The project follows:

**Detect → Backup → Apply → Reload → Audit → Roll back on failure**

No Cloudflare WARP, custom MAC daemon, macchanger, or global firewall reset is used.

## Privacy limitations

This project does not provide anonymity.

It does not hide:

- your public IP address;
- your traffic from the ISP/network operator;
- browser fingerprinting;
- application-level tracking;
- account identity;
- traffic metadata outside the protected DNS channel.

It focuses on reducing unnecessary network identity and name-resolution exposure while preserving normal IPv4/IPv6 networking.

## License

MIT License. See [LICENSE](LICENSE).
