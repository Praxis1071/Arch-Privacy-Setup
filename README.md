# Arch Linux / CachyOS Privacy Auto-Setup

An automated privacy-oriented setup script for Arch-based Linux systems such as CachyOS.

The project automates boot-time MAC address randomization and Cloudflare WARP setup while keeping the configuration focused on NetworkManager and systemd.

## Features

- **Automatic network interface detection** — detects the active physical interface and ignores common virtual interfaces such as Docker, bridges, WireGuard, TUN and VM interfaces.
- **MAC address randomization** — assigns a randomized MAC address during boot.
- **NetworkManager integration** — configures NetworkManager so its MAC handling does not conflict with the macchanger service.
- **Cloudflare WARP** — installs and enables a service that reconnects WARP during system startup.
- **Connectivity-check configuration** — disables NetworkManager captive-portal connectivity checks.
- **Idempotent setup** — can be run again to update the configuration safely.
- **Error-aware installation** — handles already registered or connected WARP states without treating them as fatal errors.

## Usage

> **Do not run `setup.sh` with `sudo ./setup.sh`.**
>
> Run it as a normal user. The script requests `sudo` only for operations that require elevated privileges. Running the whole script as root can break AUR builds because `makepkg` intentionally refuses to run as root.

### Method 1 — Run the local script

```bash
chmod +x setup.sh
./setup.sh
```

### Method 2 — Download and run

```bash
curl -fsSL https://raw.githubusercontent.com/Praxis1071/Arch-Privacy-Setup/main/setup.sh | bash
```

Review any remote script before executing it on a system you care about.

## Requirements

- Arch Linux or another Arch-based distribution
- NetworkManager
- systemd
- `sudo`
- An AUR helper such as `yay` or `paru`, or permission for the script to install `yay-bin`
- Cloudflare WARP

The script can install the required AUR helper when one is not already available, after asking for confirmation.

## Important notes

- The setup changes systemd units and NetworkManager configuration.
- AUR packages should be reviewed before installation.
- Captive-portal detection is disabled by the generated NetworkManager configuration.
- On systems with multiple physical network interfaces, verify the selected interface.
- If you switch between Wi-Fi and Ethernet, run the setup again so the generated macchanger service targets the current interface.
- MAC changes and WARP startup can temporarily interrupt network connectivity.
- The script intentionally does **not** perform an automatic `curl` connectivity test during installation.

After setup, verify WARP manually:

```bash
warp-cli --accept-tos status
curl -s https://www.cloudflare.com/cdn-cgi/trace
```

The trace output should report `warp=on` when WARP is active.

## Removal

```bash
sudo systemctl disable --now macchanger.service warp-autoconnect.service
sudo rm /etc/systemd/system/macchanger.service /etc/systemd/system/warp-autoconnect.service
sudo rm /etc/NetworkManager/conf.d/10-mac-preserve.conf /etc/NetworkManager/conf.d/20-connectivity.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager
warp-cli disconnect
```

## License

GNU General Public License v3 or later (GPL-3.0-or-later). See [LICENSE](LICENSE).