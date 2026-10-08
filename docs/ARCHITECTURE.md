# Architecture

The project uses NetworkManager and systemd-resolved as the primary native mechanisms. The NetworkManager `systemd-resolved` DNS backend is selected explicitly so per-connection DNS-over-TLS and DNSSEC settings have a supported backend. NetworkManager documents that these settings have no effect without a compatible DNS plugin.

## Implemented layers

### MAC privacy
- Wi-Fi: `802-11-wireless.cloned-mac-address=random`.
- Ethernet: `802-3-ethernet.cloned-mac-address=random`.
- Explicit user MAC policies are preserved.
- No `macchanger`, custom MAC daemon, firewall flush, or forced NetworkManager restart.

### Wi-Fi scan privacy
NetworkManager scan randomization is explicitly enabled with `wifi.scan-rand-mac-address=yes`.

Global connection defaults also cover associated Wi-Fi/Ethernet MAC randomization, so newly created profiles inherit the privacy policy when their per-profile values remain at the global default.

### Encrypted DNS
- Quad9: `9.9.9.9`, `149.112.112.112`.
- IPv6 Quad9: `2620:fe::fe`, `2620:fe::9`.
- TLS SNI: `dns.quad9.net`.
- DNS-over-TLS is required, not opportunistic.
- DNSSEC is enabled.
- DHCP-provided DNS is ignored on managed profiles.

The implementation requires an active `systemd-resolved` service because NetworkManager's DNS-over-TLS setting requires a compatible DNS backend. The current NetworkManager documentation identifies `dns-systemd-resolved` as a supported DoT plugin.

The audit verifies configuration, but it does not claim packet-level proof of encrypted DNS. Quad9's documentation recommends packet capture of port 853 when verifying encrypted DNS.

### DHCP privacy
- IPv4 DHCP client identifier: `stable`.
- IPv4 IAID: `stable`.
- DHCP hostnames are not sent.
- IPv6 DUID: `stable-uuid`.
- IPv6 IAID: `stable`.

These avoid deriving DHCP identity directly from the permanent hardware MAC.

### IPv6 privacy
- SLAAC interface identifiers: `stable-privacy` (RFC7217).
- Temporary IPv6 addresses are preferred (RFC4941).
- IPv6 remains enabled; the project does not disable IPv6.

### Local-network privacy
- LLMNR: disabled.
- mDNS: disabled.

This reduces local hostname/service exposure. It can affect local discovery, AirPrint/Chromecast-style discovery, `.local` names, and some LAN workflows. Rollback restores the previous values.

## Safety model

Before changing a managed connection, every property touched by the project is recorded under. List-valued DNS properties are normalized to nmcli's comma-separated representation before being encoded, so rollback does not collapse multiple DNS servers into one malformed value:

`/var/lib/arch-privacy-setup/`

The project-owned NetworkManager scan configuration is also backed up.

The setup follows:

**Detect → Backup → Apply → Reload → Audit → Roll back on failure**

The active connection is not forcibly disconnected by the setup script.

## Rollback

Run:

`./rollback.sh`

Rollback works from local state and does not require internet access. It restores all recorded connection properties and the previous project-owned NetworkManager configuration.

It does not uninstall packages, remove unrelated profiles, flush nftables, or forcibly restart NetworkManager.

Rollback verifies every restored connection property and the project-owned configuration file. Any verification or restore error preserves the state directory for another attempt.
