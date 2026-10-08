# Architecture

Phase 1 uses NetworkManager-native MAC randomization.

- Wi-Fi profiles use `802-11-wireless.cloned-mac-address=random`.
- Ethernet profiles use `802-3-ethernet.cloned-mac-address=random`.
- Existing explicit MAC policies are preserved.
- Active connections are not forcibly restarted.
- No custom daemon, macchanger service, firewall flush, or NetworkManager restart is used.

NetworkManager documents `random` as generating a random MAC on each connection activation. Therefore the same design applies to home/router Wi-Fi and phone-hotspot Wi-Fi. It does **not** require cooperation from the upstream router/hotspot beyond accepting a normal client MAC.

Hardware validation remains required before Phase 1 is declared fully complete.
