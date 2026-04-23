#!/bin/bash

# Script Backup Konfigurasi Fedora Silverblue
# Berfungsi untuk mencadangkan seluruh setting Flatpak, dotfiles (.bashrc/.zshrc), dan App Config

set -e

BACKUP_NAME="silverblue_backup_$(date +%F).tar.gz"
BACKUP_DIR="$HOME"

echo "======================================"
echo "Memulai Proses Backup Konfigurasi..."
echo "======================================"

echo "Mencadangkan folder-folder berikut:"
echo "- ~/.config (Config Sistem & Aplikasi GUI)"
echo "- ~/.var/app (Konfigurasi & Save Data Flatpak)"
echo "- ~/.local/share/fonts (Microsoft Fonts dll)"
echo "- ~/.local/share/gnome-shell/extensions (GNOME Extensions)"
echo "- ~/.local/share/icons & themes (Visual Kustom)"
echo "- ~/.ssh (SSH Keys)"
echo "- ~/.bashrc & ~/.zshrc (Shell Configs)"

cd $HOME

# Ekspor pengaturan desktop GNOME (dconf) agar posisi panel & extension tersimpan murni
dconf dump / > ~/.config/gnome_dconf_settings_backup.ini

# Proses pembuatan file tarball (kompresi)
tar -czvf "$BACKUP_NAME" \
  .config \
  .var/app \
  .local/share/fonts \
  .local/share/gnome-shell/extensions \
  .local/share/icons \
  .local/share/themes \
  .ssh \
  .bashrc \
  .bash_profile \
  .zshrc \
  .gitconfig \
  2>/dev/null

echo "======================================"
echo "✅ Backup Selesai!"
echo "📍 File backup tersimpan di: $BACKUP_DIR/$BACKUP_NAME"
echo "⚠️  Pindahkan file .tar.gz ini ke HDD atau Flashdisk eksternal yang aman!"
echo "======================================"
