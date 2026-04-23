# Fixing Video Preview on Fedora Silverblue

## Problem

Video files (MOV, MP4) show a black screen when:
- Previewing with spacebar in Nautilus
- Using Nemo file manager preview
- Opening with Flatpak GNOME Videos (Totem)

## Root Causes

1. **Missing proprietary codecs** - Fedora doesn't include H.264/H.265 codecs by default
2. **Flatpak sandboxing** - Flatpak apps can't access system codecs or all filesystem locations

## Solution

### Step 1: Install System Codecs (via RPM Fusion)

```bash
# Add RPM Fusion repositories (if not already added)
sudo rpm-ostree install \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install GStreamer codecs
sudo rpm-ostree install \
  gstreamer1-plugins-ugly \
  gstreamer1-plugins-bad-freeworld \
  --allow-inactive

# Reboot to apply
sudo systemctl reboot
```

### Step 2: Install Flatpak Codec Extensions

```bash
# Install ffmpeg-full extension (choose version matching your runtime, e.g., 24.08)
flatpak install flathub org.freedesktop.Platform.ffmpeg-full

# Install extra codecs
flatpak install flathub org.freedesktop.Platform.codecs-extra
```

### Step 3: Use Flathub Version of Sushi (Nautilus Previewer)

The Fedora version uses a different runtime. Replace it with the Flathub version:

```bash
flatpak remove org.gnome.NautilusPreviewer
flatpak install flathub org.gnome.NautilusPreviewer
```

### Step 4: Grant Filesystem Access to Sushi

Sushi only has `home:ro` access by default. Grant full read access:

```bash
flatpak override --user --filesystem=host:ro org.gnome.NautilusPreviewer
```

**Or use Flatseal:**
1. Open Flatseal
2. Select **Sushi**
3. Under **Filesystem**, enable **"All system files"**

### Step 5: Fix GNOME Videos (Totem) Permissions (if using Flatpak)

```bash
flatpak override --user --filesystem=home org.gnome.Totem
```

## Verification

- Open Nautilus and navigate to a folder with video files
- Press **Spacebar** on a video file
- Video preview should now play with video and audio

## Notes

- Flatpak apps are sandboxed and cannot use system libraries directly
- Each Flatpak runtime (e.g., `org.freedesktop.Platform/24.08`) needs its own codec extensions
- The Fedora Flatpak runtime (`org.fedoraproject.Platform`) doesn't use Flathub codec extensions

## Packages Installed

| Type | Package |
|------|---------|
| System | `gstreamer1-plugins-ugly` |
| System | `gstreamer1-plugins-bad-freeworld` |
| Flatpak | `org.freedesktop.Platform.ffmpeg-full` |
| Flatpak | `org.freedesktop.Platform.codecs-extra` |
| Flatpak | `org.gnome.NautilusPreviewer` (from Flathub) |
