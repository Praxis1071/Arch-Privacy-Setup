# Arch Linux / CachyOS Privacy Auto-Setup

An automated privacy-oriented setup for Arch-based Linux systems such as CachyOS.

The project combines NetworkManager's native MAC privacy features with Cloudflare WARP while keeping the network recovery logic conservative and reversible.

## Features

- **Automatic physical interface detection** — ignores common virtual interfaces, including Docker, WireGuard, TUN/TAP and Cloudflare WARP.
- **Native NetworkManager MAC privacy** — uses NetworkManager instead of a separate macchanger systemd service.
- **Per-network Wi-Fi identity** — Wi-Fi uses `stable-ssid`, so the same SSID gets a stable local MAC while different SSIDs get different MACs.
- **Stable Ethernet identity** — Ethernet uses NetworkManager's native `stable` MAC mode.
- **No NetworkManager daemon restart for MAC changes** — configuration is reloaded through `nmcli general reload conf`; the active Wi-Fi connection is only reactivated when needed.
- **Cloudflare WARP** — installs and enables automatic WARP startup.
- **WARP network resilience** — re-synchronizes WARP after NetworkManager connection changes through a dedicated recovery service and dispatcher.
- **End-to-end WARP verification** — verifies Cloudflare's trace endpoint and expects `warp=on`, rather than trusting `warp-cli status` alone.
- **Safe WARP recovery** — retries a broken tunnel once and disconnects WARP if the data path still fails, preserving ordinary Internet access.
- **Idempotent setup** — can be run again without recreating the old macchanger architecture.
- **Migration cleanup** — removes the previous macchanger service and obsolete NetworkManager MAC-preserve configuration without uninstalling packages owned by the user.

## MAC privacy architecture

The project intentionally does **not** run `macchanger` as a boot-time systemd service.

NetworkManager itself supports:

- `stable-ssid` for Wi-Fi: the generated MAC is based on the SSID, so the same network receives a stable local MAC and different networks receive different MACs.
- `stable` for Ethernet: the generated MAC is derived from the NetworkManager connection identity and host key.

This avoids the previous race between macchanger, NetworkManager activation/restarts, and WARP tunnel state.

The new architecture is:

~~~text
NetworkManager native MAC policy
        ↓
Wi-Fi / Ethernet connection
        ↓
normal network path
        ↓
Cloudflare WARP
        ↓
trace verification
        ↓
if WARP fails → disconnect WARP → preserve normal Internet
~~~

NetworkManager documents `stable-ssid` as a per-SSID hashed MAC and `stable` as a hashed MAC based on the connection's stable identity.

## WARP / NetworkManager compatibility

The setup order is deliberately conservative:

1. Remove any old macchanger service/configuration created by earlier versions.
2. Configure NetworkManager's native MAC defaults.
3. Reload NetworkManager configuration without restarting the daemon.
4. Disconnect any existing WARP tunnel before a required Wi-Fi reactivation.
5. Reactivate the current Wi-Fi profile only when its MAC property is unset, allowing the native `stable-ssid` policy to take effect.
6. Start WARP only after a real default route exists.
7. Verify the end-to-end path with Cloudflare's trace endpoint.
8. If the first WARP path fails, reconnect once.
9. If the second attempt fails, disconnect WARP so ordinary Internet access is not left behind a broken tunnel.
10. Repeat WARP recovery when NetworkManager reports a relevant connection change.

The project does **not** globally flush nftables rules and does not restart NetworkManager as part of MAC randomization.

Cloudflare's current Linux documentation recommends the sequence `warp-cli registration new`, `warp-cli connect`, and verification through:

~~~bash
curl https://www.cloudflare.com/cdn-cgi/trace
~~~

The trace should contain `warp=on` when WARP is active.

## Usage

> **Do not run setup.sh with sudo ./setup.sh.**
>
> Run it as a normal user. The script requests sudo only for operations that require elevated privileges. Running the whole script as root can break AUR builds because makepkg intentionally refuses to run as root.

### Method 1 — Run the local script

~~~bash
chmod +x setup.sh
./setup.sh
~~~

### Method 2 — Download and run

~~~bash
curl -fsSL https://raw.githubusercontent.com/Praxis1071/Arch-Privacy-Setup/main/setup.sh | bash
~~~

Review any remote script before executing it on a system you care about.

## Requirements

- Arch Linux or another Arch-based distribution
- NetworkManager
- systemd
- sudo
- An AUR helper such as yay or paru, or permission for the script to install yay-bin
- Cloudflare WARP

The setup no longer requires the `macchanger` package.

## Important notes

- The setup changes NetworkManager configuration and systemd units.
- AUR packages should be reviewed before installation.
- On systems with multiple physical network interfaces, verify the selected interface.
- Existing Wi-Fi profiles with an explicit `cloned-mac-address` value are respected. The setup does not overwrite those user choices.
- Wi-Fi profiles without an explicit MAC policy use the global `stable-ssid` default.
- MAC changes are applied by NetworkManager during connection activation. The project does not manipulate the kernel MAC directly.
- The active Wi-Fi connection may be briefly disconnected and reconnected once during setup so the native policy can take effect. NetworkManager itself is not restarted.
- WARP is disconnected before that controlled Wi-Fi reactivation to avoid coupling a tunnel transition with a MAC transition.
- The setup does **not** globally flush nftables rules.
- Re-running the setup migrates old macchanger installations to the native NetworkManager design.

After setup, verify:

~~~bash
nmcli -g 802-11-wireless.cloned-mac-address connection show "YOUR-WIFI-PROFILE"
ip link show wlan0
warp-cli --accept-tos status
curl -s https://www.cloudflare.com/cdn-cgi/trace
~~~

For a profile that inherits the global default, the connection property may be empty while NetworkManager applies `stable-ssid` during activation. The actual kernel MAC shown by `ip link` is the authoritative result.

## Removal

To remove only the components created by this setup:

~~~bash
sudo systemctl disable --now warp-autoconnect.service warp-network-recover.service
sudo rm -f /etc/systemd/system/warp-autoconnect.service
sudo rm -f /etc/systemd/system/warp-network-recover.service
sudo rm -f /usr/local/libexec/arch-privacy-warp-connect
sudo rm -f /etc/NetworkManager/dispatcher.d/90-arch-privacy-warp
sudo rm -f /etc/NetworkManager/conf.d/20-arch-privacy-mac.conf
sudo systemctl daemon-reload
sudo nmcli general reload conf
warp-cli --accept-tos disconnect
~~~

If you are migrating from an older release, the setup also removes the old `macchanger.service` and `10-mac-preserve.conf` automatically.

This does not uninstall Cloudflare WARP or the `macchanger` package. The project never removes packages that the user may have installed for other purposes.

## License

MIT License. See LICENSE.
