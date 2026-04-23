# Immutable OS Configurations & Fixes

This repository contains my personal configurations, troubleshooting guides, setup scripts, and fixes for Fedora-based immutable operating systems.

To keep things clean, the repository is divided into OS-specific directories:

## 🗂️ Repository Structure

### 🟦 [silverblue/](./silverblue/)

Contains setup scripts, configurations, and fixes specific to **Fedora Silverblue**.

- **Setup & Automation Scripts:**
  - `silverblue_install_packages.sh`: Automated package installation.
  - `silverblue_setup_configs.sh` / `silverblue_backup.sh` / `silverblue_restore_configs.sh`: Scripts to manage, backup, and restore system configs and dotfiles.
- **Video & Streaming Fixes:**
  - `v4l2loopback` tools (`load-v4l2loopback.sh`, `README-v4l2loopback.md`, service files): Setup for virtual cameras in OBS.
  - `firefox-obs-camera-fix.md`: Fix for Firefox not recognizing OBS virtual cameras.
  - `vesktop-distrobox-screenshare-fix.md`: Fixes for screen sharing via Vesktop inside Distrobox.
  - `Troubleshooting Discord Screen Share Rubberbanding.md`: Guides to fix Discord screen share lag/rubberbanding.
  - `fedora-silverblue-video-preview-fix.md`: Fixes for video thumbnails/previews in the file manager.
- **Networking:**
  - `smb-clean.conf`: Clean Samba configuration.

### 🟪 [bazzite/](./bazzite/)

Contains guides and configurations specific to **Bazzite** (the gaming-focused Fedora Kinoite/Silverblue fork by ublue-os).

- `bazzite-gnome-gaming-mode-setup.md`: A complete guide on how to rebase to the `-deck` image, set GNOME as the primary default boot session, and easily switch securely into Steam's Gamescope "Gaming Mode" UI without triggering SDDM login loops.
