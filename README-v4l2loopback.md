# Panduan & Log Troubleshooting `v4l2loopback` (OBS Virtual Camera) di OS dengan rpm-ostree

Dokumen ini merekap kendala dan langkah perbaikan yang kita coba di Fedora Silverblue dengan partisi LUKS dan Secure Boot aktif.

## Status: ✅ SOLVED (28 Maret 2026)

Virtual camera **sudah bisa digunakan** via systemd service + insmod + auto-sign.

## Akar Masalah (Root Cause Analysis)

### 1. Secure Boot & Kernel Keyring Mismatch
- Modul `v4l2loopback.ko` yang di-build oleh `akmods` **TIDAK ter-sign** secara otomatis.
- Key MOK (`fedora_1774423351_4efbbd94`) sudah enrolled dan masuk `.platform` keyring.
- `.machine` keyring kosong karena `shim 15.8` di Fedora tidak memasukkan MOK ke `.machine` keyring untuk self-signed certificates.
- Kernel lockdown mode `integrity` (Secure Boot) menolak loading unsigned module.

### 2. Kompresi XZ & modprobe
- `modprobe` memuat file `.ko.xz` via `finit_module()` syscall — gagal karena module unsigned.
- `insmod` memuat file `.ko` (non-compressed) via `init_module()` — **berhasil** jika module sudah di-sign manual.

### 3. SELinux & Systemd Service
- Systemd service yang load module dari `/var/home/` (home directory) di-block oleh SELinux.
- SELinux menolak `module_load` dari file berlabel `user_home_t`.
- **Fix**: Simpan module di `/var/lib/v4l2loopback/` dengan label `modules_object_t`.

### 4. Boot Timing (DefaultDependencies=no)
- Service awal pakai `DefaultDependencies=no` → jalan sebelum `/tmp` di-mount → error "Read-only file system".
- **Fix**: Hapus `DefaultDependencies=no`, tambah `After=local-fs.target`.

### 5. Systemd $ Variable Escaping
- `$VARIABLE` di dalam ExecStart/ExecStartPre diinterpretasi sebagai systemd environment variable, bukan bash variable.
- **Fix**: Gunakan script `.sh` terpisah.

### 6. Script `akmods` Gagal Install Lokal
- Build RPM **berhasil**, tapi instalasi gagal:
  ```
  DNF not found, using YUM instead.
  /usr/sbin/akmods: line 413: yum: command not found
  ```
- Fedora 43 menggunakan `dnf5`, bukan `yum`. Script `akmods` belum di-update.

## Solusi Final: Systemd Service + Script + Auto-Sign

### File yang digunakan:

#### 1. Script loader: `/usr/local/bin/load-v4l2loopback.sh`
```bash
#!/usr/bin/bash
MODDIR="/var/lib/v4l2loopback"
KVER="$(uname -r)"
KOFILE="${MODDIR}/v4l2loopback-${KVER}.ko"
SRCKO="/lib/modules/${KVER}/extra/v4l2loopback/v4l2loopback.ko.xz"
SIGNFILE="/usr/src/kernels/${KVER}/scripts/sign-file"
PRIVKEY="/etc/pki/akmods/private/private_key.priv"
PUBKEY="/etc/pki/akmods/certs/public_key.der"

mkdir -p "$MODDIR"

if [ ! -f "$KOFILE" ]; then
    echo "v4l2loopback: Building signed module for kernel ${KVER}..."
    if [ ! -f "$SRCKO" ]; then
        echo "ERROR: Module source not found: $SRCKO"; exit 1
    fi
    xz -d -k "$SRCKO" --stdout > "$KOFILE"
    if [ -f "$SIGNFILE" ] && [ -f "$PRIVKEY" ] && [ -f "$PUBKEY" ]; then
        "$SIGNFILE" sha256 "$PRIVKEY" "$PUBKEY" "$KOFILE"
    else
        echo "ERROR: Signing tools/keys not found"; rm -f "$KOFILE"; exit 1
    fi
    chcon -t modules_object_t "$KOFILE" 2>/dev/null
fi

/usr/sbin/insmod "$KOFILE" exclusive_caps=1 card_label="OBS Virtual Camera"
```

#### 2. Systemd service: `/etc/systemd/system/v4l2loopback-load.service`
```ini
[Unit]
Description=Load v4l2loopback kernel module (Secure Boot workaround)
After=systemd-modules-load.service local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
SELinuxContext=system_u:system_r:unconfined_service_t:s0
ExecStart=/usr/local/bin/load-v4l2loopback.sh
ExecStop=/usr/sbin/rmmod v4l2loopback

[Install]
WantedBy=multi-user.target
```

### Setup (sudah dilakukan):
```bash
sudo mkdir -p /var/lib/v4l2loopback
sudo cp load-v4l2loopback.sh /usr/local/bin/load-v4l2loopback.sh
sudo chmod +x /usr/local/bin/load-v4l2loopback.sh
sudo cp v4l2loopback-load.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable v4l2loopback-load.service
```

### Saat Kernel Update (otomatis!)
Script otomatis mendeteksi kernel baru dan akan:
1. Extract `.ko` dari `.ko.xz` yang dibuild oleh akmods
2. Sign dengan MOK key
3. Set SELinux label `modules_object_t`
4. Load via `insmod`

File `.ko` lama untuk kernel sebelumnya tetap ada di `/var/lib/v4l2loopback/` dan bisa dihapus manual.

## MOK Enrollment (Sudah Selesai)
1. ✅ Key pair dibuat oleh `kmodgenca`
2. ✅ Key public diimport via `mokutil --import`
3. ✅ Enrolled via MOK Manager saat boot
4. ✅ Key terlihat di `mokutil --list-enrolled` (key 2, fingerprint `32:A1:F4:76:...`)
5. ✅ Key masuk `.platform` keyring saat boot

## Info Sistem
- OS: Fedora Silverblue 43
- Kernel: 6.19.8-200.fc43.x86_64 (dan seterusnya)
- Shim: 15.8-3.x86_64
- Secure Boot: Enabled
- Lockdown: integrity
- v4l2loopback: 0.15.3
