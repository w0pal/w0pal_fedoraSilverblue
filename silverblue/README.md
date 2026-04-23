# Panduan Lengkap Instalasi & Optimasi Fedora Silverblue (Ext4)

Dokumen ini berisi rangkuman seluruh konfigurasi, _troubleshooting_, dan optimasi yang telah kita diskusikan untuk sistem Fedora Silverblue kamu. Simpan file ini sebagai referensi jika sewaktu-waktu ingin melakukan instalasi ulang.

---

## 1. Instalasi Fedora Silverblue dengan Partisi Ext4

Agar sistem jauh lebih ringan dan bebas hambatan I/O di SSD SATA, instal ulang menggunakan filesystem **Ext4** (menggantikan BTRFS bawaan).

1. Masuk ke _installer_ Anaconda Fedora Silverblue.
2. Pada bagian **Installation Destination**, pilih **Custom** (bukan Automatic).
3. Hapus seluruh partisi BTRFS bawaan yang sudah ada.
4. Buat partisi manual (Standard Partition):
   - `/boot/efi` (EFI System Partition) — ukuran `512MB`
   - `/boot` (Ext4) — ukuran `1GB`
   - `/` atau root (Ext4) — ukuran **sisanya**. Centang opsi **Encrypt** (LUKS) jika ingin disk tetap terlindungi.
5. Lanjutkan instalasi seperti biasa.

---

## 2. Auto-Unlock LUKS dengan TPM2.0 (Anti-Reset saat Update)

Agar Fedora Silverblue tidak menanyakan password LUKS berulang kali setiap kali sistem melakukan update `rpm-ostree`, kita mengikatnya ke PCR 7.

1. Identifikasi partisi LUKS kamu (misal: `/dev/nvme0n1p3` atau `/dev/sdb3`).
2. Jalankan perintah ini untuk mendaftarkan TPM2.0:
   ```bash
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/sdbX
   ```
3. **Reset/Hapus TPM (Opsional):** Jika suatu saat kamu ingin menghapus konfigurasi _auto-unlock_ (misal saat ingin update BIOS atau ganti perangkat keras), hapus identitas TPM pada LUKS dengan perintah:
   ```bash
   sudo systemd-cryptenroll /dev/sdbX --wipe-slot=tpm2
   ```
   _(Ganti `/dev/sdbX` dengan lokasi partisi LUKS aslimu)._

---

## 3. Konfigurasi LDM Dynamic Disk (Mount HDD Windows Read/Write)

Windows LDM tidak langsung terbaca di Linux. Butuh _tools_ tambahan agar termount otomatis saat _booting_.

1. **Install dependensi:**
   ```bash
   sudo rpm-ostree install libldm ntfs3-progs
   ```
2. **Buat service aktivator LDM** (`sudo nano /etc/systemd/system/ldmtool.service`):

   ```ini
   [Unit]
   Description=LDM Tool
   After=local-fs-pre.target
   Before=local-fs.target

   [Service]
   Type=oneshot
   ExecStart=/usr/bin/ldmtool create all
   RemainAfterExit=yes

   [Install]
   WantedBy=local-fs.target
   ```

3. **Buat service Auto-Mount** (`sudo nano /etc/systemd/system/mnt-windows--hdd.mount`):

   ```ini
   [Unit]
   Description=Mount Windows HDD

   [Mount]
   What=/dev/mapper/ldm_vol_WIN_12345
   Where=/mnt/windows-hdd
   Type=ntfs3
   Options=rw,uid=1000,gid=1000,umask=022

   [Install]
   WantedBy=multi-user.target
   ```

   _(Pastikan nama file `.mount` persis sesuai struktur `Where`, contoh `/mnt/windows-hdd` menjadi `mnt-windows--hdd.mount`. Ganti `What=` dengan nama map ldm volume aslimu)._

4. **Enable keduanya:**
   ```bash
   sudo systemctl enable ldmtool.service mnt-windows--hdd.mount
   ```

---

## 4. Perbaikan Steam Recording (Error Export / Codec)

Untuk membuka blokiran _Hardware Encoding_ di AMD Radeon RX (Fitur H.264/HEVC dihapus oleh Fedora karena paten).

1. Tukar driver Mesa bawaan dengan versi RPM Fusion (Freeworld):
   ```bash
   sudo rpm-ostree override remove mesa-va-drivers \
     --install mesa-va-drivers-freeworld \
     --install mesa-va-drivers-freeworld.i686 \
     --idempotent
   ```
2. Restart PC.
3. Buka **Steam Settings > Game Recording**. Jika _Export_ masih gagal, ubah format dari HEVC (H.265) menjadi **H.264**.

---

## 5. Discord / Vesktop Flatpak: Fix Rich Presence

Aplikasi Discord bentuk Flatpak diisolasi di _sandbox_, membuat Steam gagal mendeteksi aktivitas _(Playing Game)_.

1. Alih-alih menambahkan `--filesystem=xdg-run/discord-ipc-0` (yang bisa menyebabkan crash pada rilis flatpak baru), cara yang disarankan adalah memberi Discord/Vesktop akses ke status Steam melalui environment variable atau folder lokal jika memungkinkan tanpa map `xdg-run/discord-ipc-0` langsung.
2. Restart Discord. Status game Steam kamu otomatis muncul.

---

## 6. Integrasi OBS Virtual Camera (Droidcam)

Memastikan OBS Virtual Camera tidak rusak/hilang setelah update Kernel OS.

1. **Install modul mandiri:**
   ```bash
   sudo rpm-ostree install kmod-v4l2loopback
   ```
2. **Setup permanen:**
   ```bash
   sudo sh -c 'echo "options v4l2loopback exclusive_caps=1 card_label=\"OBS Virtual Camera\"" > /etc/modprobe.d/v4l2loopback.conf'
   ```

---

## 7. Penyesuaian I/O & Memori (Performa Mulus)

Meskipun kamu sudah menggunakan Ext4, modifikasi virtual memory CPU tetap penting untuk menghindari aplikasi Electron (Chrome/Discord) yang rakus RAM.

1. Ubah batas toleransi _Swap_ dan _Dirty Pages_ latar belakang:
   ```bash
   sudo bash -c 'cat > /etc/sysctl.d/99-io-fix.conf << EOF
   vm.swappiness=10
   vm.dirty_ratio=20
   vm.dirty_background_ratio=5
   EOF'
   ```
2. Ubah profil _Scheduler SSD_ (Agar lebih responsif):
   ```bash
   sudo bash -c 'cat > /etc/udev/rules.d/60-ssd-scheduler.rules << EOF
   ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
   EOF'
   ```

---

## 8. Ringkasan Isu Flatpak Ekstra Lainnya

- **VLC Media Player:** Jangan pakai yang dari _Fedora Remote_ (codec terpotong). Install murni dari Flathub: `flatpak install flathub org.videolan.VLC`.
- **Darktable OpenCL (No Device Found):** Install _support runtime_ grafis AMD di sandbox: `flatpak install flathub org.freedesktop.Platform.GL.default//24.08extra`
- **Minecraft Launcher:** Hindari _official launcher_ dari Flathub yang sering terkena error "Eroded Badlands" (karena _bug_ Microsoft Account OAuth di dalam sandbox). Install dan gunakan alternatif seperti **Prism Launcher** dari Flathub.

---

## 9. Lokasi Folder Save & Game Penting di Linux

Mencari lokasi file di Linux sedikit berbeda dengan Windows (C:\), terutama untuk aplikasi Flatpak atau game Windows yang berjalan menggunakan Wine/Proton.

**1. Minecraft (Flatpak)**
Bergantung pada launcher mana yang kamu gunakan, folder `.minecraft` tempat kamu bisa memasang _Shaders, Mods,_ atau memindahkan _World_ dari Windows berada di:

- **Prism Launcher (Disarankan):** `~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/<nama_instance_kamu>/.minecraft/`
- **Official Launcher:** `~/.var/app/com.mojang.Minecraft/data/minecraft/`

**2. Yakuza: Like a Dragon (GOG FitGirl Repack via Steam Proton)**
Karena kamu menambahkan game repacks ini sebagai _Non-Steam Game_ menggunakan Steam Native asli bawaan OS (bukan Flatpak), strukturnya menjadi:

- **Lokasi Install Data Game:** `<GAMEDATA_MOUNT>/Games`
- **Lokasi Save Data:** Steam otomatis beraksi membuat "Windows C: Virtual" (Prefix) tersendiri di folder `compatdata` dengan kode unik `2888456782`. Folder Save Data kamu persisnya ada di rute ini:
  `~/.local/share/Steam/steamapps/compatdata/2888456782/pfx/drive_c/users/steamuser/AppData/Roaming/Sega/YakuzaLikeADragon_GOG/`
  _(Setiap penambahan game Non-Steam baru ke depan, Steam akan membuat folder angka acak 10-digit baru di sebelah folder `2888456782` tersebut)._

---

## 10. Symlink Folder Windows ke Direktori Home (Nautilus)

Agar folder bawaan Linux (Documents, Downloads, Music, Pictures, Videos) langsung terhubung (symlink) ke HDD Windows dan terbaca resmi oleh _file manager_ Nautilus:

1. **Hapus folder bawaan Linux:**
   ```bash
   rm -rf ~/Downloads ~/Documents ~/Music ~/Pictures ~/Videos
   ```
2. **Buat Symlink ke HDD Windows:**
   _(Ganti `<HDD_WINDOWS_MOUNT>` dengan letak partisi NTFS asli komputermu kelak)_
   ```bash
   ln -s "<HDD_WINDOWS_MOUNT>/installer or zip" ~/Downloads
   ln -s "<HDD_WINDOWS_MOUNT>/Documents" ~/Documents
   ln -s "<HDD_WINDOWS_MOUNT>/music" ~/Music
   ln -s "<HDD_WINDOWS_MOUNT>/photos" ~/Pictures
   ln -s "<HDD_WINDOWS_MOUNT>/video" ~/Videos
   ```
3. **Daftarkan rute absolutnya ke XDG User Dirs:**
   Agar aplikasi lain (_browser_, _save dialog_) paham rute barunya, ubah isi file `~/.config/user-dirs.dirs`:
   ```bash
   cat << 'EOF' > ~/.config/user-dirs.dirs
   XDG_DESKTOP_DIR="$HOME/Desktop"
   XDG_DOWNLOAD_DIR="<HDD_WINDOWS_MOUNT>/installer or zip"
   XDG_TEMPLATES_DIR="$HOME/Templates"
   XDG_PUBLICSHARE_DIR="$HOME/Public"
   XDG_DOCUMENTS_DIR="<HDD_WINDOWS_MOUNT>/Documents"
   XDG_MUSIC_DIR="<HDD_WINDOWS_MOUNT>/music"
   XDG_PICTURES_DIR="<HDD_WINDOWS_MOUNT>/photos"
   XDG_VIDEOS_DIR="<HDD_WINDOWS_MOUNT>/video"
   EOF
   ```

---

## 11. Setup Samba (File Sharing) di Fedora Silverblue

Agar bisa berbagi file antar PC di jaringan lokal via protokol SMB:

1. **Install Samba (butuh restart OS):**
   ```bash
   sudo rpm-ostree install samba
   ```
2. **Edit Konfigurasi Samba (`/etc/samba/smb.conf`):**
   Buat atau edit file `/etc/samba/smb.conf`, misal untuk berbagi folder Public:

   ```ini
   # See smb.conf.example for a more detailed config file or
   # read the smb.conf manpage.
   # Run 'testparm' to verify the config is correct after
   # you modified it.
   #
   # Note:
   # SMB1 is disabled by default. This means clients without support for SMB2 or
   # SMB3 are no longer able to connect to smbd (by default).

   [global]
           workgroup = SAMBA
           security = user

           passdb backend = tdbsam

           printing = cups
           printcap name = cups
           load printers = yes
           cups options = raw

           # Install samba-usershares package for support
           include = /etc/samba/usershares.conf

   [WindowsHDD]
           path = <HDD_WINDOWS_MOUNT>
           browsable = yes
           writable = yes
           guest ok = no
           read only = no
           create mask = 0755

   [gamedata]
           path = <GAMEDATA_MOUNT>
           browsable = yes
           writable = yes
           guest ok = no
           read only = no
   ```

3. **Buat Password Samba untuk Usermu:**
   ```bash
   sudo smbpasswd -a homepc
   ```
4. **Izinkan Akses SELinux (Wajib di Fedora):**
   ```bash
   # Karena share kamu berada di partisi eksternal (di luar /home), gunakan mode Export All:
   sudo setsebool -P samba_export_all_rw 1
   ```
5. **Buka Port Firewall:**
   ```bash
   sudo firewall-cmd --permanent --add-service=samba
   sudo firewall-cmd --reload
   ```
6. **Nyalakan Service Samba:**
   ```bash
   sudo systemctl enable --now smb nmb
   ```

---

## 12. Install Microsoft Fonts (Cara Aman untuk Silverblue)

Karena arsitektur Fedora Silverblue melarang modifikasi folder `/usr/share/fonts` secara langsung, cara terbaik dan paling aman untuk menginstall font Windows (Arial, Times New Roman, Calibri, dll) adalah dengan menaruhnya di dalam folder pengguna lokal (tanpa perlu lewat `rpm-ostree`).

Tinggal jalankan rentetan perintah ini di terminal:

```bash
# 1. Buat folder fonts khusus di home directory kamu
mkdir -p ~/.local/share/fonts/mscorefonts

# 2. Masuk ke folder tersebut
cd ~/.local/share/fonts/mscorefonts

# 3. Download & Ekstrak bundel arsip paket MS Fonts yang populer di internet
curl -s -L -O "https://github.com/ahrm/ms-fonts/archive/refs/heads/master.zip"
unzip -q master.zip
mv ms-fonts-master/* .
rm -rf ms-fonts-master master.zip

# 4. Refresh database font Linux kamu
fc-cache -fv
```

_(Font Microsoft milikmu kini sudah langsung dapat digunakan di LibreOffice, Antigravity/VSCode, maupun aplikasi Flatpak mana saja, dan dijamin **tidak akan hilang** biarpun PC di-restart atau Silverblue update ke versi terbaru)._

---

## 13. Manajemen Repositori (RPM Fusion & Copr)

Karena Fedora secara default memblokir aplikasi non-free (tertutup paten seperti mp3, h264, discord, steam), kamu harus menyalakan Repositori Pihak Ketiga:

**1. Menyalakan RPM Fusion (Free & Non-Free):**

```bash
sudo rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

**2. Menambahkan Repositori Custom (Antigravity & Copr):**
Karena Fedora Silverblue murni berbasis `rpm-ostree` dan tidak memiliki `dnf` bawaan aktif, perintah lawas seperti `dnf copr enable` akan membuahkan error. Cara resminya di Silverblue adalah mendaftarkan URL repositori tersebut secara mentah-mentah ke folder `/etc/yum.repos.d/`.

Salin dan eksekusi blok ini sekaligus di terminal kamu:

```bash
# Repo Antigravity
sudo bash -c 'cat > /etc/yum.repos.d/antigravity.repo << \EOF
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOF'

# Repo Copr PyCharm
sudo bash -c 'cat > /etc/yum.repos.d/phracek-PyCharm.repo << \EOF
[copr:copr.fedorainfracloud.org:phracek:PyCharm]
name=Copr repo for PyCharm owned by phracek
baseurl=https://download.copr.fedorainfracloud.org/results/phracek/PyCharm/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/phracek/PyCharm/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF'

# Repo Copr Ghostty Terminal
sudo bash -c 'cat > /etc/yum.repos.d/scottames-ghostty.repo << \EOF
[copr:copr.fedorainfracloud.org:scottames:ghostty]
name=Copr repo for ghostty owned by scottames
baseurl=https://download.copr.fedorainfracloud.org/results/scottames/ghostty/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/scottames/ghostty/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF'
```

---

## 14. Skrip Otomatisasi Instalasi & System Backup (Modular)

Daripada repot melakukan langkah nomor 1-13 di atas satu per satu secara manual saat kamu memutuskan _clean install_ kelak, kamu bisa menggunakan 4 buah _script Bash_ modular yang membedah _workflow_ instalasi menjadi beberapa babak:

**Script 1: `silverblue_backup.sh`**
Jalankan di Fedora kamu sekarang juga sebelum memutuskan install ulang OS. Script ini akan membungkus seluruh sejarah konfigurasi aplikasi, cache, data rahasia SSH, dan Flatpak (berupa isi direktori `~/.config`, `~/.var/app`, `~/.local/share/fonts`, dll) ke dalam file `silverblue_backup_... .tar.gz`. Simpan file hasil _backup_ ini di HDD Windows!

**Script 2: `silverblue_install_packages.sh`**
Si _Automator_ Paket Dasar. Setelah OS baru terinstall, jalankan script ini **pertama kali**. Ia bertugas memborong unduhan seluruh aplikasi Flatpak, mendaftarkan Repository RPM Fusion / Copr, hingga menanam codec Mesa Freeworld dan kawan-kawannya lewat `rpm-ostree`. Setelah script ini rampung, PC **wajib di-restart**.

**Script 3: `silverblue_setup_configs.sh`**
Si _Automator_ Konfigurasi Cerdas. Jalankan **setelah kamu restart dari langkah kedua**. Script ini tidak butuh internet sama sekali. Ia akan mendeteksi keberadaan LUKS, HDD LDM Windows, dan BTRFS GameData menggunakan `lsblk` otomatis, kemudian menjahit _Symlink_ folder Nautilus, mengaktifkan Sysctl I/O Fix, hingga membuat fondasi _Systemd Service_ untuk Samba dan kawan-kawan dari angka 1-13 sebelumnya. Tanpa keringat!

**Script 4: `silverblue_restore_configs.sh`**
Langkah termanis. Panggil ini untuk mengekstrak dan menimpakan kembali seluruh isi wadah _backup_ `.tar.gz` yang telah kamu buat di awal tadi kepada rumah `/home` barumu, mengembalikan keajaiban Desktop kamu persis posisi aslinya.

_(Keempat file bash script `.sh` ini sudah kujamin aman dan sangat ramah untuk dikoleksi ke dalam repositori **GitHub** pribadimu)._
