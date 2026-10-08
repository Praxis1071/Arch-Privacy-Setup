# Architecture

## Current state

Phase 0 deliberately contains only the migration/cleanup entry point. It removes components owned by the previous WARP-based implementation without installing a replacement network policy.

## Target state

The new implementation will be layered:

```text
setup.sh
  |
  +-- detection
  |
  +-- configuration
  |
  +-- verification
  |
  +-- rollback
  |
  +-- audit
```

Feature layers will be implemented independently:

- MAC privacy
- Wi-Fi scan privacy
- encrypted DNS
- DHCP identity hardening
- IPv6 privacy
- local network discovery policy

Each layer must have:

1. a clear privacy objective,
2. minimal system changes,
3. a live-state verification method,
4. a failure condition,
5. a rollback path,
6. automated static tests where possible,
7. real-hardware validation for networking behavior.

The architecture intentionally does not include a WARP tunnel, a custom MAC-changing daemon, or a global firewall reset.
