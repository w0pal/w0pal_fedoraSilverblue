# Log: Fix v4l2loopback Permanent (28 Mar 2026)

## 4 Masalah & Fix

1. **Boot Timing**: `DefaultDependencies=no` → `/tmp` belum ready. Fix: `After=local-fs.target`
2. **Systemd $ Escaping**: `$VAR` jadi systemd env. Fix: script `.sh` terpisah
3. **Module Unsigned**: akmods nggak sign. Fix: `sign-file sha256 key.priv key.der module.ko`
4. **SELinux**: `user_home_t` blocked. Fix: simpan di `/var/lib/v4l2loopback/`, label `modules_object_t`

## Solusi Final
- Script: `/usr/local/bin/load-v4l2loopback.sh` (auto extract, sign, set label, load)
- Service: `/etc/systemd/system/v4l2loopback-load.service`
- Hasil: `Active: active (exited)` ✅

## Kernel Update Gagal?
```
sudo akmods --force --akmod v4l2loopback --kernels $(uname -r)
sudo rm /var/lib/v4l2loopback/v4l2loopback-$(uname -r).ko
sudo systemctl restart v4l2loopback-load.service
```

---

## rpm-ostree upgrade Error (28 Mar 2026)

### Masalah
Setelah reboot berhasil, `rpm-ostree upgrade` error:
```
error: Could not depsolve transaction; 1 problem detected:
 Problem: package kernel-uki-virt-6.19.8-200.fc43 requires kernel-modules-core-uname-r = 6.19.8
  - kmod-v4l2loopback-6.19.8-200.fc43.x86_64-0.15.3-1.fc43 requires kernel-uname-r = 6.19.8
  - cannot install both kernel-modules-core-6.19.8 and kernel-modules-core-6.19.9 from @System
```

### Root Cause
`kmod-v4l2loopback` di-install sebagai **LocalPackage** yang ter-pin ke kernel 6.19.8.
Saat upgrade ke 6.19.9, terjadi konflik dependency kernel.

Cek via `rpm-ostree status`:
```
LocalPackages: kmod-v4l2loopback-6.19.8-200.fc43.x86_64-0.15.3-1.fc43.x86_64
```

### Fix
Hapus kmod LocalPackage yang ter-pin ke kernel lama:
```bash
sudo rpm-ostree uninstall kmod-v4l2loopback-6.19.8-200.fc43.x86_64-0.15.3-1.fc43.x86_64
```

Lalu upgrade jalan normal:
```bash
sudo rpm-ostree upgrade
# kernel 6.19.8-200.fc43 → 6.19.9-200.fc43 ✅
```

### Catatan
- `akmod-v4l2loopback` tetap ada di LayeredPackages → akan build `.ko.xz` untuk kernel baru
- Script `load-v4l2loopback.sh` otomatis extract + sign + load saat kernel baru boot
- **Tidak perlu install kmod manual lagi** — cukup akmod + systemd service

### Potensi Issue: Boot Ordering
Kalau `akmods.service` belum selesai sebelum `v4l2loopback-load.service` jalan → module gagal load.

Fix: tambah di `/etc/systemd/system/v4l2loopback-load.service`:
```ini
[Unit]
After=systemd-modules-load.service local-fs.target akmods.service
```

Lalu:
```bash
sudo systemctl daemon-reload
```

Kalau setelah reboot virtual camera mati, jalankan manual (lihat bagian "Kernel Update Gagal?" di atas).
