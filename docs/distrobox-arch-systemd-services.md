# Distrobox Arch (`dev-image`) Service Integration

## Diagnosis

Your `dev-image` Distrobox container is functioning normally, but it is **not running a full system `systemd` manager** for system scope.  
Because of that:

- `systemctl` (system scope) fails with:
  - `System has not been booted with systemd as init system (PID 1). Can't operate.`
- `systemctl --user` works and shows active user services.

Confidence: **High**

## Immediate Fix (Minimal Risk)

Run services as **user units** inside the Distrobox container.

```bash
distrobox enter dev-image -- bash -lc 'mkdir -p ~/.config/systemd/user'
# Place your unit files in ~/.config/systemd/user/*.service
distrobox enter dev-image -- systemctl --user daemon-reload
distrobox enter dev-image -- systemctl --user enable --now <your-service>.service
```

## Durable Fix

Choose one model and keep it consistent:

1. **Recommended for Distrobox**: run long-lived services as `systemd --user` units in the container.
2. **Need full system-level systemd in a container**: use a dedicated Podman setup designed for systemd + cgroups (not standard Distrobox flow).
3. **Host-integrated daemons**: run them on the host as user units, and keep Distrobox for dev tooling.

## Rollback

```bash
distrobox enter dev-image -- systemctl --user disable --now <your-service>.service
distrobox enter dev-image -- rm -f ~/.config/systemd/user/<your-service>.service
distrobox enter dev-image -- systemctl --user daemon-reload
```

## Verification

```bash
distrobox enter dev-image -- systemctl --user status <your-service>.service --no-pager
distrobox enter dev-image -- systemctl --user is-active <your-service>.service
distrobox enter dev-image -- journalctl --user -u <your-service>.service -n 50 --no-pager
```

Healthy state:

- `is-active` returns `active`
- `status` shows `running`
- no crash/restart loop in `journalctl`
