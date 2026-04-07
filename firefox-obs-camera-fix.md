# Fixing OBS Virtual Camera in Firefox Flatpak (Fedora Silverblue)

## Problem

Firefox Flatpak cannot detect OBS Virtual Camera when using video conferencing or camera test websites.

## Root Cause

Firefox Flatpak uses **PipeWire Camera Portal** by default for webcam access. This portal-based approach can have issues detecting v4l2loopback virtual cameras like OBS Virtual Camera.

## Prerequisites

Ensure the OBS Virtual Camera (v4l2loopback) is loaded and working:

```bash
# Check if v4l2loopback module is loaded
lsmod | grep v4l2loopback

# Check video devices
ls -la /dev/video*

# Check if PipeWire sees the camera
wpctl status | grep -A15 "Video"
```

Expected output should show:
- `v4l2loopback` module loaded
- `/dev/video0` (or similar) device
- "OBS Virtual Camera" in WirePlumber video devices

## Solution

### Step 1: Ensure WirePlumber V4L2 Monitor is Enabled

Create a WirePlumber configuration to ensure v4l2 devices are monitored:

```bash
mkdir -p ~/.config/wireplumber/wireplumber.conf.d

cat > ~/.config/wireplumber/wireplumber.conf.d/10-enable-v4l2.conf << 'EOF'
monitor.v4l2.rules = [
  {
    matches = [
      {
        device.name = "~v4l2_device.*"
      }
    ]
    actions = {
      update-props = {
        device.disabled = false
      }
    }
  }
]

wireplumber.profiles = {
  main = {
    monitor.v4l2 = required
  }
}
EOF

# Restart WirePlumber to apply
systemctl --user restart wireplumber
```

### Step 2: Grant Firefox Device Access

Ensure Firefox has access to all devices:

```bash
flatpak override --user --device=all org.mozilla.firefox
```

### Step 3: Disable PipeWire Camera Portal in Firefox

This is the **key fix**. Firefox's PipeWire camera portal doesn't work well with v4l2loopback virtual cameras.

**Option A: Via about:config (Recommended)**

1. Open Firefox
2. Navigate to `about:config`
3. Accept the risk warning
4. Search for: `media.webrtc.camera.allow-pipewire`
5. Set it to `false`
6. Restart Firefox

**Option B: Via user.js file**

```bash
# Find your Firefox profile directory
PROFILE_DIR=$(find ~/.var/app/org.mozilla.firefox/config/mozilla/firefox/ -name "*.default-release" -type d | head -1)

# Add the preference
echo 'user_pref("media.webrtc.camera.allow-pipewire", false);' >> "$PROFILE_DIR/user.js"
```

### Step 4: Restart Firefox

Close Firefox completely and restart it.

## Verification

1. Start OBS and enable Virtual Camera (Tools → Start Virtual Camera)
2. Open Firefox and visit [webcamtests.com](https://webcamtests.com) or [webcammictest.com](https://webcammictest.com)
3. Allow camera access when prompted
4. Select "OBS Virtual Camera" from the camera dropdown
5. You should see your OBS output

## Troubleshooting

### Camera still not detected

Check if OBS Virtual Camera is running:

```bash
# Check v4l2 devices
v4l2-ctl --list-devices

# Check PipeWire sees it
pw-cli list-objects | grep -i "OBS Virtual"
```

### Multiple video devices

If you have multiple cameras, the OBS Virtual Camera might be on a different device:

```bash
ls /dev/video*
```

### Reset Firefox camera permissions

If you previously denied camera access:

1. Go to `about:preferences#privacy`
2. Scroll to "Permissions"
3. Click "Settings..." next to Camera
4. Remove any blocked entries
5. Try again

## Summary of Changes

| Component | Change |
|-----------|--------|
| WirePlumber | Added `10-enable-v4l2.conf` to ensure v4l2 devices are enabled |
| Firefox Flatpak | Granted `device=all` permission |
| Firefox Config | Set `media.webrtc.camera.allow-pipewire` to `false` |

## Related Files

- `~/.config/wireplumber/wireplumber.conf.d/10-enable-v4l2.conf` - WirePlumber v4l2 config
- `~/.var/app/org.mozilla.firefox/config/mozilla/firefox/*.default-release/user.js` - Firefox preferences

## Notes

- The `v4l2loopback` kernel module is required for OBS Virtual Camera
- On Fedora Silverblue, install it with: `sudo rpm-ostree install akmod-v4l2loopback`
- PipeWire Camera Portal works fine with physical webcams, but virtual cameras need V4L2 direct access
- This fix applies specifically to Firefox Flatpak; native Firefox installations may work differently
