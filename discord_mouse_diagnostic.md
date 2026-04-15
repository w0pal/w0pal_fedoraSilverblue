# 🖱️ Discord Screen Share — Mouse Rubber Banding Diagnostic

## System Summary

| Component | Value |
|---|---|
| **Host OS** | Fedora 43 Silverblue (immutable) |
| **Kernel** | 6.19.11-200.fc43.x86_64 |
| **Desktop** | GNOME on Wayland |
| **GPU** | AMD Radeon RX 470/480/570/580 (Ellesmere) |
| **Monitor** | Xiaomi Mi Monitor via HDMI-1 |
| **Resolution** | 1920×1080 @ **180 Hz** |
| **Display Scale** | 1× (no fractional scaling) |
| **Discord** | Flatpak `com.discordapp.Discord` v0.0.132 |
| **Vesktop** | Flatpak `dev.vencord.Vesktop` v1.6.5 (also installed) |
| **Mouse profile** | Flat (no acceleration) |
| **HW Acceleration** | Enabled in Discord |
| **Antigravity** | Running inside Arch Linux distrobox |

---

## 🔍 Root Cause Analysis

Your friend's observation is correct — there are **three compounding factors** causing the mouse rubber banding during screen share:

### 1. 🎯 **180 Hz Refresh Rate + Screen Capture Mismatch** (Primary Cause)

> [!IMPORTANT]
> Your monitor is running at **180 Hz**, but Discord's screen capture via PipeWire/WebRTC encodes at **30 fps** (or 60 fps at most). This creates a massive synchronization gap.

The hardware cursor on your desktop moves at 180 Hz native. When Discord captures the screen, it samples frames at a much lower rate. The cursor position "snaps" between sampled positions, causing what your friend sees as rubber banding — the cursor appears to jump forward, snap back, and teleport erratically on the receiving end.

### 2. 🧩 **Electron + Wayland Screen Sharing Limitations**

The official Discord Flatpak uses an older Electron that has known deficiencies with Wayland's PipeWire screen-sharing portal. It doesn't properly handle hardware cursor compositing for the stream, which compounds the 180 Hz problem.

### 3. ⚠️ **Missing `discord-flags.conf`**

> [!NOTE]
> You have **no** `discord-flags.conf` file at `~/.var/app/com.discordapp.Discord/config/discord-flags.conf`. This means Discord is launching with default Electron flags, missing several Wayland optimization flags.

---

## 🛠️ Solutions (Ranked by Effectiveness)

### ✅ Solution 1: Use Vesktop Instead (Recommended — Easiest)

You already have **Vesktop v1.6.5** installed! Vesktop is purpose-built for Linux and handles PipeWire screen sharing natively with much better cursor handling.

**Steps:**
1. Open Vesktop instead of the official Discord client
2. Go to **Settings → Vesktop Settings** and ensure:
   - Screen sharing uses PipeWire (should be default)
3. Test screen sharing with your friend

> [!TIP]
> Vesktop uses Vencord under the hood, which you already have configured. Your plugins and settings will carry over.

---

### ✅ Solution 2: Add Discord Electron Flags (If You Want to Keep Official Discord)

Create the missing flags file to optimize Discord for Wayland:

```bash
cat > ~/.var/app/com.discordapp.Discord/config/discord-flags.conf << 'EOF'
--enable-features=UseOzonePlatform,WebRTCPipeWireCapturer,WaylandWindowDecorations
--ozone-platform=wayland
--enable-wayland-ime
EOF
```

These flags:
- Force Discord to use **native Wayland** (not XWayland)
- Enable PipeWire-based screen capture (better frame sync)
- Enable Wayland input method support

After creating the file, **fully quit and relaunch Discord**.

---

### ✅ Solution 3: Disable Hardware Acceleration in Discord

Your Discord has `enableHardwareAcceleration: true`. Toggling it off can sometimes resolve cursor sync issues:

1. Open Discord → **Settings** → **Voice & Video** → **Advanced**
2. Toggle **Hardware Acceleration** → **OFF**
3. Restart Discord
4. Test screen share

> [!WARNING]
> This may make Discord itself feel slightly less smooth, but it can fix the rubber banding on the remote viewer's end.

---

### ✅ Solution 4: Lower Monitor Refresh Rate During Screen Share

Since the root cause is a 180 Hz → 30 fps mismatch, you can temporarily lower your refresh rate:

```bash
# From the host system (not distrobox), run:
gnome-randr modify HDMI-1 -r 60
```

Or simply go to **GNOME Settings → Displays → Refresh Rate → 60 Hz** before starting a screen share, and switch back to 180 Hz after.

---

### 🔧 Solution 5: Use OBS Virtual Camera as a Workaround

Since you have **OBS Studio v32.1.1** installed, you can use the OBS Virtual Camera approach:

1. Open OBS → Add a **Screen Capture** source
2. Start **Virtual Camera** in OBS
3. In Discord, share the OBS virtual camera feed instead of your screen

> [!NOTE]
> You previously set up v4l2loopback for this (from past conversations). If it's still working, this is a very reliable workaround.

---

## 📊 Quick Decision Matrix

| Solution | Effort | Effectiveness | Side Effects |
|---|---|---|---|
| **Vesktop** | ⭐ Low | ⭐⭐⭐ High | None (already installed) |
| **Discord flags** | ⭐ Low | ⭐⭐ Medium | May break if Discord updates |
| **Disable HW accel** | ⭐ Low | ⭐⭐ Medium | Discord may feel slightly sluggish |
| **Lower refresh rate** | ⭐⭐ Medium | ⭐⭐⭐ High | Your desktop loses 180 Hz temporarily |
| **OBS Virtual Camera** | ⭐⭐⭐ Higher | ⭐⭐⭐ High | Extra app running, more CPU usage |

---

## 📌 Additional Notes

- **This is NOT a problem with your mouse hardware or settings.** Your flat acceleration profile and mouse speed settings are perfectly fine.
- **This is NOT caused by the distrobox/Antigravity container.** The container only affects the terminal environment, not your display server or Discord.
- **Flatpak sandboxing is correctly configured.** Discord has all the necessary permissions (Wayland, PipeWire, devices).
- **Your GPU (RX 580 class) is plenty capable.** This is a software protocol issue, not a hardware limitation.
