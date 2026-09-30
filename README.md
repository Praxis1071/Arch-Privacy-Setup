# Arch Linux / CachyOS Privacy Auto-Setup

An automated privacy-oriented setup for Arch-based Linux systems such as CachyOS.

The project automates boot-time MAC address randomization and Cloudflare WARP setup while keeping the configuration focused on NetworkManager and systemd.

## Features

- **Automatic network interface detection** — detects the active physical interface and ignores common virtual interfaces such as Docker, bridges, WireGuard, TUN and VM interfaces.
- **MAC address randomization** — assigns a randomized MAC address during boot.
- **NetworkManager integration** — configures NetworkManager so its MAC handling does not conflict with the macchanger service.
- **Cloudflare WARP** — installs and enables a service that reconnects WARP during system startup.
- **WARP network resilience** — re-synchronizes WARP after NetworkManager connection changes, including Wi-Fi/hotspot reconnects and DHCP changes, through a dedicated recovery service.
- **End-to-end WARP verification** — does not treat warp-cli status alone as proof of working Internet traffic; it verifies the Cloudflare trace endpoint and expects warp=on.
- **Safe WARP recovery** — if WARP reports connected but its data path is broken, the setup retries the tunnel and disconnects the broken tunnel rather than leaving the host without normal Internet access.
- **Connectivity-check configuration** — disables NetworkManager captive-portal connectivity checks.
- **Idempotent setup** — can be run again to update the configuration safely.
- **Error-aware installation** — handles already registered or connected WARP states without treating them as fatal errors.

## WARP / NetworkManager compatibility

The setup deliberately avoids connecting WARP before restarting NetworkManager. The previous order could leave WARP's tunnel/firewall state out of sync when NetworkManager was restarted afterwards.

The current order is:

1. Configure NetworkManager.
2. Disconnect any existing WARP tunnel before restarting NetworkManager.
3. Restart NetworkManager.
4. Wait for a real default route.
5. Connect WARP.
6. Verify the end-to-end path with Cloudflare's trace endpoint.
7. Re-run the WARP connection when NetworkManager reports a relevant interface change.

NetworkManager dispatcher events are used instead of modifying routing tables or flushing nftables globally. This keeps the fix scoped to WARP and avoids destroying unrelated firewall state.

Cloudflare's Linux documentation also recommends verifying the actual data path with:

~~~bash
curl --silent https://www.cloudflare.com/cdn-cgi/trace | grep '^warp=on$'
~~~

See the official Cloudflare documentation for the current WARP CLI and verification workflow.

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

The script can install the required AUR helper when one is not already available, after asking for confirmation.

## Important notes

- The setup changes systemd units and NetworkManager configuration.
- AUR packages should be reviewed before installation.
- Captive-portal detection is disabled by the generated NetworkManager configuration.
- On systems with multiple physical network interfaces, verify the selected interface.
- If you switch between Wi-Fi and Ethernet, run the setup again so the generated macchanger service targets the current interface.
- MAC changes and WARP startup can temporarily interrupt network connectivity.
- WARP recovery intentionally prefers restoring ordinary Internet connectivity over leaving a broken WARP tunnel in place.
- The setup does **not** globally flush nftables rules. Existing firewall rules outside WARP are left intact.

After setup, verify WARP manually:

~~~bash
warp-cli --accept-tos status
curl -s https://www.cloudflare.com/cdn-cgi/trace
~~~

The trace output should report warp=on when WARP is active.

## Removal

If you want to remove only the components created by this setup:

~~~bash
sudo systemctl disable --now macchanger.service warp-autoconnect.service warp-network-recover.service
sudo rm -f /etc/systemd/system/macchanger.service
sudo rm -f /etc/systemd/system/warp-autoconnect.service
sudo rm -f /etc/systemd/system/warp-network-recover.service
sudo rm -f /usr/local/libexec/arch-privacy-warp-connect
sudo rm -f /etc/NetworkManager/dispatcher.d/90-arch-privacy-warp
sudo rm -f /etc/NetworkManager/conf.d/10-mac-preserve.conf
sudo rm -f /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager
warp-cli --accept-tos disconnect
~~~

This does not uninstall Cloudflare WARP itself.

## License

GNU General Public License v3 or later (GPL-3.0-or-later). See LICENSE.
