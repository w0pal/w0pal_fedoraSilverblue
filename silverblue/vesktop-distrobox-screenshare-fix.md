# Fix Vesktop Screen Share di Distrobox (Error 2011/2012)

## Status: ✅ SOLVED (22 April 2026)

Screen share Vesktop dari Arch Linux container (distrobox) ke Discord sudah bisa berjalan setelah install portal backend yang hilang.

---

## Setup Sistem

| Komponen | Detail |
|----------|--------|
| Host OS | Fedora Silverblue 43 (Wayland / GNOME) |
| Monitor | HDMI, 180Hz native refresh |
| Container | Arch Linux distrobox (`dev-image`) |
| Vesktop | `vesktop-electron 1.6.5-1` (AUR, pakai system Electron) |
| Electron | v39.5.2 (package `electron39`, **sudah ada H.264**) |
| Portal Host | `xdg-desktop-portal-gnome` (active) |
| PipeWire | Active di host |

---

## Gejala (Symptoms)

- Screen share **kadang jalan, kadang tidak** — Error 2011 atau 2012
- Error 2011 = "Video Streamer Timeout" (sisi streamer)
- Error 2012 = "Video Streamer Timeout" (sisi viewer)
- Stream dari HP selalu works, dari PC intermittent
- Portal picker GNOME kadang muncul, kadang tidak
- Kalau muncul dan berhasil capture, stream tetap bisa timeout

---

## Akar Masalah (Root Cause)

### 1. Portal Backend Hilang di Container

Container punya `xdg-desktop-portal` tapi **TIDAK** punya backend:
- ❌ `xdg-desktop-portal-gnome` — handles ScreenCast, Screenshot
- ❌ `xdg-desktop-portal-gtk` — handles FileChooser, AppChooser

Akibatnya folder `/usr/share/xdg-desktop-portal/portals/` **kosong** — portal tidak tahu harus routing request ScreenCast ke mana.

**Error log dari journal:**
```
ERROR:third_party/webrtc/modules/desktop_capture/linux/wayland/screencast_portal.cc:369
  Failed to start the screen cast session.

ERROR:third_party/webrtc/modules/desktop_capture/linux/wayland/base_capturer_pipewire.cc:93
  ScreenCastPortal failed: 2

Error during screenshare picker Failed to get sources.
TypeError: Video was requested, but no video stream was provided
```

### 2. Kenapa Kadang Jalan?

D-Bus session bus di-share antara host dan distrobox container. Ketika host portal service baru start (setelah boot), D-Bus name `org.freedesktop.impl.portal.desktop.gnome` sudah terdaftar oleh host. Container bisa "kebetulan" nyambung ke host portal — dan stream jalan.

Tapi setelah portal restart, atau ada zombie process yang interfere, routing gagal.

### 3. Zombie Portal Process

Ditemukan `xdg-desktop-portal-gtk` dari **hari sebelumnya** (PID 2940, start 21 Apr) masih berjalan dan mengganggu routing D-Bus.

### 4. Tidak Ada `portals.conf`

Tanpa file `~/.config/xdg-desktop-portal/portals.conf`, portal tidak punya preferensi eksplisit untuk routing ScreenCast.

---

## Solusi

### Step 1: Install Portal Backend di Container

```bash
sudo pacman -S --noconfirm xdg-desktop-portal-gtk xdg-desktop-portal-gnome
```

Ini menambahkan file `.portal` ke `/usr/share/xdg-desktop-portal/portals/`:
- `gnome.portal` — mendefinisikan ScreenCast, RemoteDesktop, Screenshot routing ke GNOME backend
- `gtk.portal` — mendefinisikan FileChooser, AppChooser routing ke GTK backend

### Step 2: Buat Portal Config

```bash
mkdir -p ~/.config/xdg-desktop-portal
cat > ~/.config/xdg-desktop-portal/portals.conf << 'EOF'
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.ScreenCast=gnome
org.freedesktop.impl.portal.RemoteDesktop=gnome
org.freedesktop.impl.portal.Screenshot=gnome
EOF
```

### Step 3: Restart Portal Services

```bash
# Dari dalam distrobox:
distrobox-host-exec systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal

# Dari host langsung:
systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
```

### Step 4: Restart Vesktop

Tutup Vesktop sepenuhnya (termasuk system tray), lalu buka lagi.

---

## Konfigurasi Vesktop

### Electron Flags (`~/.config/vesktop-flags.conf`)

```
--ozone-platform-hint=auto
--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer
--enable-webrtc-pipewire-capturer
```

### Settings (`~/.config/vesktop/settings.json`)

```json
{
    "discordBranch": "stable",
    "minimizeToTray": true,
    "arRPC": true,
    "hardwareVideoAcceleration": false,
    "customTitleBar": false
}
```

> **Catatan:** `hardwareVideoAcceleration` di-set `false` karena hardware encoding AMD (VAAPI) di Wayland bisa gagal diam-diam dan menyebabkan timeout.

### Patch `app.asar` untuk System Audio di Wayland

Vesktop secara default **melewatkan** (skip) screen share picker di Wayland dan langsung mengambil layar pertama TANPA audio. Ini karena kode berikut:

```javascript
// Kode asli (Wayland path):
if(kE) { // kE = isLinux && isWayland
    let l = i[0];
    await et("screenshare:picker", {screens:[l], skipPicker:true}); // skip picker!
    t(l ? {video: n[0]} : {});  // HANYA video, TIDAK ada audio!
    return;  // early return, audio handler NEVER runs
}
```

**Masalah:** `skipPicker:true` menyebabkan komponen `ScreenSharePicker` langsung submit dengan `includeSources: "None"`, sehingga `VesktopNative.virtmic.start()` / `startSystem()` **tidak pernah dipanggil**.

**Fix:** Patch `app.asar` untuk menghapus Wayland early-return block, sehingga full picker muncul dengan opsi "Stream With Audio":

```bash
# Extract
cd /tmp && mkdir -p vesktop_patch
npx --yes asar extract /usr/lib/vesktop/app.asar ./vesktop_patch/extracted

# Patch: hapus Wayland early-return block
python3 << 'PYEOF'
import re
with open('/tmp/vesktop_patch/extracted/dist/js/main.js', 'r') as f:
    content = f.read()
match = re.search(r'if\(kE\)\{.{0,300}return\}', content)
if match:
    content = content[:match.start()] + '/* kE block removed - full picker with audio on Wayland */' + content[match.end():]
    print("✅ Patched")
with open('/tmp/vesktop_patch/extracted/dist/js/main.js', 'w') as f:
    f.write(content)
PYEOF

# Repack dan install
npx --yes asar pack /tmp/vesktop_patch/extracted /tmp/patched_app.asar
sudo cp /tmp/patched_app.asar /usr/lib/vesktop/app.asar
```

> **Catatan:** Patch ini harus diulangi setiap kali `vesktop-electron` di-update (`yay -Syu`). Setelah update, jalankan script patch di atas lagi.

> **Hasil:** Setelah patch, saat klik "Share Screen" di Vesktop, akan muncul **Vesktop Screen Share Picker** lengkap dengan toggle "Stream With Audio" dan pilihan audio source (None / Entire System / per-app).

---

## Script Quick-Fix (`~/bin/fix-screenshare.sh`)

Kalau screen share gagal, jalankan script ini sebelum coba lagi:

```bash
#!/usr/bin/env bash
# fix-screenshare.sh — Clears stuck portal sessions and restarts services

echo "🔧 Clearing portal sessions and restarting services..."

if [ -n "$CONTAINER_ID" ]; then
    distrobox-host-exec systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
else
    systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
fi

sleep 1
echo "✅ Portal services restarted. Screen sharing should work now."
notify-send "Screen Share Fix" "Portal services restarted. Try screen sharing again." \
    --icon=video-display 2>/dev/null || true
```

**Bind ke keyboard shortcut:**
1. Buka **Settings → Keyboard → Custom Shortcuts**
2. Klik **+**
3. Name: `Fix Screen Share`
4. Command: `/var/home/homepc/bin/fix-screenshare.sh`
5. Shortcut: `Super+Shift+S`

---

## Alur Screen Share (Arsitektur)

```
Vesktop (Arch container)
    │
    ├── desktopCapturer.getSources()
    │       │
    │       ▼
    ├── Electron WebRTC → ScreenCastPortal::Start()
    │       │
    │       ▼ (D-Bus session bus, shared host↔container)
    │
    ├── xdg-desktop-portal (host, PID dari systemd)
    │       │
    │       ▼ (cek .portal files → route ke gnome backend)
    │
    ├── xdg-desktop-portal-gnome (host)
    │       │
    │       ▼ (minta Mutter buat ScreenCast session)
    │
    ├── GNOME/Mutter → PipeWire stream
    │       │
    │       ▼ (video frames via PipeWire)
    │
    ├── Electron encode H.264 (via libffmpeg.so)
    │       │
    │       ▼ (WebRTC)
    │
    └── Discord servers → viewers
```

**Bandingkan dengan HP:**
```
HP → Native screen capture API → Hardware H.264 → Discord servers → viewers
```

HP cuma 1 boundary, PC lewat 6+ boundary. Makanya HP selalu lancar.

---

## Troubleshooting

### Screen share masih gagal setelah fix?

1. **Jalankan `~/bin/fix-screenshare.sh`** dulu
2. Restart Vesktop
3. Coba "Entire Screen" (lebih stabil dari per-app window)

### Cek portal sessions yang stuck:

```bash
busctl --user tree org.freedesktop.portal.Desktop
```

Kalau ada banyak session `webrtc_session*`, portal penuh. Restart:

```bash
distrobox-host-exec systemctl --user restart xdg-desktop-portal-gnome xdg-desktop-portal
```

### Cek journal untuk error:

```bash
journalctl --user --since "10 min ago" --no-pager | grep -iE "screencast|pipewire|portal|Failed"
```

### Fallback: OBS Virtual Camera

Kalau portal tetap bermasalah, metode ini **100% reliable**:

1. Buka **OBS Studio** → tambah source **Screen Capture (PipeWire)**
2. Klik **Start Virtual Camera**
3. Di Vesktop → nyalakan **Camera** → pilih "**OBS Virtual Camera**"
4. Teman kamu lihat layar kamu sebagai webcam feed — works untuk semua viewer

---

## Riwayat Masalah Sebelumnya (Kronologi)

| Tanggal | Masalah | Fix |
|---------|---------|-----|
| 15 Apr 2026 | Mouse rubber banding saat screen share Discord Flatpak | Pindah ke Vesktop |
| 15 Apr 2026 | Screen share hanya bisa 1x di Vesktop Flatpak | Restart `xdg-desktop-portal-gnome` |
| 15 Apr 2026 | Beberapa viewer tidak bisa lihat stream | H.264 codec hilang di Flatpak Vesktop |
| 18 Apr 2026 | Install Vesktop via distrobox (Arch) — ada H.264 | `vesktop-electron` dari AUR |
| 18 Apr 2026 | Portal picker tidak muncul | Install `xdg-desktop-portal` + buat flags |
| 18 Apr 2026 | Stream black screen | System D-Bus socket missing, symlink fix |
| 18 Apr 2026 | Stream masih black | Patch `app.asar` (`kE=false`) — **salah** |
| 22 Apr 2026 | Error 2011/2012, intermittent | Install `xdg-desktop-portal-gnome` + `gtk` di container ✅ |
| 22 Apr 2026 | System audio tidak terstream | Patch `app.asar` hapus Wayland skipPicker block ✅ |

---

## File yang Terlibat

| File | Fungsi |
|------|--------|
| `~/.config/vesktop-flags.conf` | Electron flags (Wayland + PipeWire) |
| `~/.config/vesktop/settings.json` | Vesktop settings (HW accel off) |
| `~/.config/xdg-desktop-portal/portals.conf` | Portal routing preferences |
| `/usr/share/xdg-desktop-portal/portals/gnome.portal` | ScreenCast routing definition |
| `/usr/share/xdg-desktop-portal/portals/gtk.portal` | GTK portal routing definition |
| `~/bin/fix-screenshare.sh` | Quick-fix restart script |
| `/usr/lib/vesktop/app.asar` | Vesktop app (patched: hapus Wayland skipPicker block) |
| `/usr/lib/electron39/libffmpeg.so` | H.264 codec (148 refs, works ✅) |
