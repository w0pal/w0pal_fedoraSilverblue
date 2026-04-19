#!/bin/bash
# Script 2: Konfigurasi Sistem Fedora Silverblue
# Dijalankan KEDUA (Setelah restart dari script instalasi paket)

set -e

echo "========================================================="
echo "Memulai Konfigurasi Sistem Otomatis..."
echo "========================================================="

echo "Mendeteksi Partisi Penyimpanan secara otomatis..."

LUKS_PARTITION=$(lsblk -rn -o NAME,FSTYPE | awk '$2=="crypto_LUKS"{print "/dev/"$1}' | head -n1)

HDD_UUID=$(lsblk -rn -o UUID,FSTYPE,LABEL | awk '$2=="ntfs" && $3=="DATA"{print $1}' | head -n1)
if [ -z "$HDD_UUID" ]; then
    HDD_UUID=$(lsblk -rn -o UUID,FSTYPE | awk '$2=="ntfs"{print $1}' | head -n1)
fi

GAME_UUID=$(lsblk -rn -o UUID,FSTYPE,LABEL | awk '$3=="gamedata"{print $1}' | head -n1)
if [ -z "$GAME_UUID" ]; then
    GAME_UUID="Gagal_Deteksi_GameData"
fi

HDD_WINDOWS_MOUNT="/var/mnt/$HDD_UUID"
GAMEDATA_MOUNT="/var/mnt/$GAME_UUID"

echo "✔ LUKS Ditemukan: $LUKS_PARTITION"
echo "✔ Windows HDD Ditemukan: $HDD_WINDOWS_MOUNT"
echo "✔ GameData Ditemukan: $GAMEDATA_MOUNT"
echo "========================================================="

echo "1. Membangun Konfigurasi Mount LDM & Samba..."
sudo bash -c 'cat > /etc/systemd/system/ldmtool.service << EOF
[Unit]
Description=LDM Tool Auto Launcher
After=local-fs-pre.target
Before=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ldmtool create all
RemainAfterExit=yes

[Install]
WantedBy=local-fs.target
EOF'

UNIT_NAME="var-mnt-${HDD_UUID}.mount"
sudo bash -c "cat > /etc/systemd/system/${UNIT_NAME} << EOF
[Unit]
Description=Auto-Mount Windows HDD
Requires=ldmtool.service
After=ldmtool.service

[Mount]
What=UUID=${HDD_UUID}
Where=${HDD_WINDOWS_MOUNT}
Type=ntfs3
Options=rw,uid=1000,gid=1000,umask=022

[Install]
WantedBy=multi-user.target
EOF"

sudo bash -c "mkdir -p /etc/samba && cat > /etc/samba/smb.conf << EOF
[global]
    workgroup = SAMBA
    security = user
    passdb backend = tdbsam
    printing = cups
    printcap name = cups
    load printers = yes
    cups options = raw
    include = /etc/samba/usershares.conf

[WindowsHDD]
    path = ${HDD_WINDOWS_MOUNT}
    browsable = yes
    writable = yes
    guest ok = no
    read only = no
    create mask = 0755

[gamedata]
    path = ${GAMEDATA_MOUNT}
    browsable = yes
    writable = yes
    guest ok = no
    read only = no
EOF"

echo "2. Setup I/O Limit & SSD Scheduler..."
sudo bash -c 'cat > /etc/sysctl.d/99-io-fix.conf << EOF
vm.swappiness=10
vm.dirty_ratio=20
vm.dirty_background_ratio=5
EOF'

sudo bash -c 'cat > /etc/udev/rules.d/60-ssd-scheduler.rules << EOF
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
EOF'

echo "3. Symlink Folder Windows ke Home (Nautilus)..."
rm -rf ~/Downloads ~/Documents ~/Music ~/Pictures ~/Videos
mkdir -p "${HDD_WINDOWS_MOUNT}/installer or zip"
mkdir -p "${HDD_WINDOWS_MOUNT}/Documents"
mkdir -p "${HDD_WINDOWS_MOUNT}/music"
mkdir -p "${HDD_WINDOWS_MOUNT}/photos"
mkdir -p "${HDD_WINDOWS_MOUNT}/video"

ln -s "${HDD_WINDOWS_MOUNT}/installer or zip" ~/Downloads
ln -s "${HDD_WINDOWS_MOUNT}/Documents" ~/Documents
ln -s "${HDD_WINDOWS_MOUNT}/music" ~/Music
ln -s "${HDD_WINDOWS_MOUNT}/photos" ~/Pictures
ln -s "${HDD_WINDOWS_MOUNT}/video" ~/Videos

cat << EOF > ~/.config/user-dirs.dirs
XDG_DESKTOP_DIR="\$HOME/Desktop"
XDG_DOWNLOAD_DIR="${HDD_WINDOWS_MOUNT}/installer or zip"
XDG_TEMPLATES_DIR="\$HOME/Templates"
XDG_PUBLICSHARE_DIR="\$HOME/Public"
XDG_DOCUMENTS_DIR="${HDD_WINDOWS_MOUNT}/Documents"
XDG_MUSIC_DIR="${HDD_WINDOWS_MOUNT}/music"
XDG_PICTURES_DIR="${HDD_WINDOWS_MOUNT}/photos"
XDG_VIDEOS_DIR="${HDD_WINDOWS_MOUNT}/video"
EOF

echo "4. Fitur Tambahan (OBS v4l2loopback)..."
sudo bash -c 'echo "options v4l2loopback exclusive_caps=1 card_label=\"OBS Virtual Camera\"" > /etc/modprobe.d/v4l2loopback.conf'

echo "========================================================="
echo "✅ Konfigurasi Sistem Selesai!"
echo ""
echo "LANGKAH MANUAL TERAKHIR:"
echo "1. Enable Service LDM & Samba: sudo systemctl enable ldmtool.service ${UNIT_NAME} smb nmb"
echo "2. Masukkan Password Samba: sudo smbpasswd -a homepc"
echo "3. SELinux: sudo setsebool -P samba_export_all_rw 1"
echo "4. Firewalld: sudo firewall-cmd --permanent --add-service=samba && sudo firewall-cmd --reload"

if [ -n "$LUKS_PARTITION" ]; then
    echo "5. Daftarkan TPM LUKS Auto-Unlock: sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 ${LUKS_PARTITION}"
fi
echo "========================================================="
