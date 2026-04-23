#!/bin/bash
# Script Restore Konfigurasi Pribadi
# Berfungsi HANYA untuk mengekstrak file backup .tar.gz ke posisinya semula

set -e

echo "======================================"
echo "Memulai Restore Konfigurasi Pribadi..."
echo "======================================"

# Mencari file backup terbaru di map saat ini
BACKUP_FILE=$(ls -t silverblue_backup_*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ File backup tidak ditemukan di folder ini!"
    echo "Pastikan file silverblue_backup_YYYY-MM-DD.tar.gz ada di folder yang sama dengan script ini."
    exit 1
fi

echo "File backup terdeteksi: $BACKUP_FILE"
echo "Mengekstrak file kembali ke Home Directory (~/)..."

# Ekstrak file tar menyimulasi struktur aslinya (berpusat dari Home)
tar -xzvf "$BACKUP_FILE" -C "$HOME/"

# Me-restore pengaturan Desktop GNOME jika file-nya tersedia
if [ -f "$HOME/.config/gnome_dconf_settings_backup.ini" ]; then
    echo "Me-restore pengaturan GNOME (Dconf)..."
    dconf load / < "$HOME/.config/gnome_dconf_settings_backup.ini"
fi

echo "======================================"
echo "✅ Restore Konfigurasi Pribadi Selesai!"
echo "Semua setting riwayat Flatpak, ~/.config, dan .bashrc/.zshrc telah kembali."
echo "======================================"
