# Bazzite: Setting GNOME as Default on Deck Image

This document outlines the process of configuring the Bazzite Deck image (`bazzite-deck-gnome`) to boot into the GNOME Desktop environment by default, while still allowing a seamless transition into the Steam UI Gamescope (Gaming Mode) session without getting stuck in a login loop.

## 1. Background

Standard Bazzite desktop images (`bazzite` or `bazzite-gnome`) do not include the standalone Gamescope session. To get the authentic Steam Deck console UI experience, you must use the Deck image:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-deck-gnome:stable
```

## 2. Setting GNOME as the Default Boot Session

To force the system to boot into GNOME instead of Gaming Mode:

```bash
# Note: On Bazzite-GNOME, the SteamOS "plasma" strings are automatically intercepted and mapped to GNOME.
steamos-session-select plasma-wayland-persistent
```

## 3. The "Log Out" Loop Issue

By default, SteamOS configures the SDDM display manager with `Relogin=true`. If your default session is set to GNOME, simply clicking "Log Out" or "Return to Gaming Mode" will close the desktop session. However, SDDM interprets the closed session as a cue to immediately log you back into your default session, trapping you in an infinite GNOME loop.

To escape the loop:

```bash
steamos-session-select gamescope
```

## 4. Creating a "Switch to Gaming Mode" Shortcut

To safely transition from GNOME to Gaming Mode without triggering the relogin loop, avoid the standard "Log Out" button. Instead, use a custom desktop shortcut that pre-switches the default session to Gamescope before terminating your session.

Create a file at `~/.local/share/applications/switch-to-gaming-mode.desktop` with the following content:

```ini
[Desktop Entry]
Name=Switch to Gaming Mode
Comment=Log out of GNOME and switch to the Steam Gamescope session
Exec=sh -c '/usr/bin/steamos-session-select gamescope && sleep 1 && pkill -KILL -u $USER'
Icon=steam
Terminal=true
Type=Application
Categories=Game;System;
```

**Workflow:**

- **Desktop -> Gaming Mode:** Click the "Switch to Gaming Mode" shortcut in your app drawer.
- **Gaming Mode -> Desktop:** Press the Steam Button -> Power -> Switch to Desktop.

## 5. Permanently Booting to GNOME (Defeating SteamOS Oneshot)

Because SteamOS assumes Gaming Mode is the absolute default, switching back to the desktop from Gaming Mode creates a "oneshot" session. This means if you reboot the PC, the oneshot token is destroyed and it boots back to Gaming Mode instead of GNOME.

To force GNOME on **every** boot, intercept SDDM with this boot service:

```bash
sh -c 'cat << EOF > /tmp/force-gnome-boot.service
[Unit]
Description=Force GNOME Session as Default Boot
After=sddm.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "echo -e \"[Autologin]\nSession=gnome-wayland.desktop\" > /etc/sddm.conf.d/zz-steamos-autologin.conf"

[Install]
WantedBy=graphical.target
EOF'
```

Enable it by running:

```bash
pkexec cp /tmp/force-gnome-boot.service /etc/systemd/system/
pkexec systemctl enable force-gnome-boot.service
```

---

## 6. Checking the Current Boot Default

To verify what session your PC will boot into next, inspect the SDDM autologin configuration:

```bash
cat /etc/sddm.conf.d/zz-steamos-autologin.conf
```

- If it says `Session=gnome-wayland-oneshot.desktop` or `gnome-wayland.desktop`, it will boot to GNOME.
- If it says `Session=gamescope-session.desktop`, it will boot to Gaming Mode.

---

## 💡 Bonus: Finding GOG Save Files (Flatpak Steam)

If you uninstall the Steam Flatpak, the compatdata remains inside your home directory. For a game like _Yakuza: Like a Dragon_ (GOG version), the save files can be found here:

```bash
/var/home/homepc/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/<APP_ID>/pfx/drive_c/users/steamuser/AppData/Roaming/Sega/YakuzaLikeADragon_GOG
```

_(Since Distrobox shares the host's `/var/home` directory, you can access these files normally inside or outside the container)._
