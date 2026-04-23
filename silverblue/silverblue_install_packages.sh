#!/bin/bash
# Script 1: Instalasi Paket Fedora Silverblue
# Dijalankan PERTAMA KALI setelah install ulang OS.

set -e

echo "========================================================="
echo "Memulai Instalasi Paket (RPM-Ostree & Flatpak)..."
echo "Pastikan koneksi internet stabil!"
echo "========================================================="

echo "1. Menambahkan Repositori RPM Fusion & Copr..."
sudo rpm-ostree install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo bash -c 'cat > /etc/yum.repos.d/antigravity.repo << \EOF
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOF'

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
echo "2. Setup Instalasi rpm-ostree & Driver Mesa-Freeworld..."
sudo rpm-ostree override remove \
  libavdevice-free libavfilter-free libavformat-free ffmpeg-free libpostproc-free \
  libswresample-free libavutil-free libavcodec-free libswscale-free mesa-va-drivers \
  --install ffmpeg --install mesa-va-drivers-freeworld --install mesa-va-drivers-freeworld.i686 \
  --install gstreamer1-plugins-bad-free-extras --install gstreamer1-plugins-bad-freeworld \
  --install gstreamer1-plugins-ugly --install android-tools --install antigravity \
  --install btop --install cargo --install clinfo --install earlyoom --install fastfetch \
  --install fzf --install ghostty --install gnome-tweaks --install goverlay \
  --install gstreamer1-plugin-openh264 --install htop --install libldm \
  --install ntfs3-progs --install mesa-libOpenCL --install rocm-opencl \
  --install samba --install seahorse --install steam --install steam-devices \
  --install v4l2loopback --install vim --install zoxide --install zsh --install lact \
  --idempotent

echo "3. Menginstall Aplikasi Flatpak..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-modify --no-filter flathub

flatpak install flathub -y \
  com.bilingify.readest com.discordapp.Discord com.github.tchx84.Flatseal \
  com.google.Chrome com.mojang.Minecraft com.obsproject.Studio \
  com.spotify.Client com.stremio.Stremio com.visualstudio.code \
  dev.vencord.Vesktop io.github.thetumultuousunicornofdarkness.cpu-x \
  io.mrarm.mcpelauncher net.davidotek.pupgui2 org.darktable.Darktable \
  org.exaile.Exaile org.onlyoffice.desktopeditors org.qbittorrent.qBittorrent \
  org.videolan.VLC org.freedesktop.Platform.GL.default//24.08extra

echo "========================================================="
echo "✅ Instalasi Paket Selesai!"
echo "🔄 HARAP RESTART PC ANDA SEKARANG untuk mengaplikasikan rpm-ostree!"
echo "Setelah restart, barulah jalankan script: silverblue_setup_configs.sh"
echo "========================================================="
