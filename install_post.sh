#!/bin/bash

# Sicherstellen, dass das Skript als root ausgeführt wird
if [[ $EUID -ne 0 ]]; then
  echo "Dieses Skript muss als root ausgeführt werden!"
  exit 1
fi

echo "Aktiviere TRIM-Unterstützung für SSDs..."

# 1. Prüfen, ob der Scheduler "fstrim.timer" verfügbar ist
if systemctl list-timers | grep -q fstrim.timer; then
  echo "Aktiviere den fstrim.timer für periodisches TRIM..."
  systemctl enable fstrim.timer
  systemctl start fstrim.timer
  echo "fstrim.timer wurde aktiviert und gestartet."
else
  echo "Warnung: fstrim.timer ist auf diesem System nicht verfügbar."
fi

# 2. Sofortiges TRIM ausführen
echo "Führe TRIM sofort aus..."
fstrim -av

# 3. Erfolgsmeldung
echo "TRIM wurde aktiviert und auf allen unterstützten Partitionen ausgeführt."

sudo systemctl enable --now ufw
echo "UFW wurde aktiviert"

sudo systemctl enable --now NetworkManager.service

# Zsh als Standard-Shell für den aktuellen Benutzer setzen
echo "Setze Zsh als Standard-Shell für den Benutzer $USER..."
chsh -s "$(which zsh)" "$USER"

# NVIDIA changes
# Define the bootloader entries directory and mkinitcpio config file path
bootloader_entries_dir="/boot/loader/entries"
mkinitcpio_config="/etc/mkinitcpio.conf"

# 1. Navigate to the bootloader entries directory
cd "$bootloader_entries_dir" || exit 1

# 2. Find the bootloader entry file ending with "_linux.conf"
filename=$(ls *_linux.conf | head -n 1)

if [[ -f "$filename" ]]; then
    # Backup the file before modifying
    sudo cp "$filename" "$filename.bak"

    # Append the necessary options to the conf file
    sudo sed -i '/options/s/$/ nvidia-drm.modeset=

# Nvidia hook
# echo "Creating pacman hook for NVIDIA..."
cat > /etc/pacman.d/hooks/nvidia.hook <<EOF
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
# You can remove package(s) that don't apply to your config, e.g. if you only use nvidia-open you can remove nvidia-lts as a Target
Target=nvidia
Target=nvidia-open
Target=nvidia-lts
# If running a different kernel, modify below to match
Target=linux

[Action]
Description=Updating NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF

sudo mkdir -p /games

# Auto create FSTAB for home labeled partition
UUID=$(lsblk -o UUID,LABEL | grep 'home' | awk '{print $1}')

# Check if UUID was found
if [ -z "$UUID" ]; then
    echo "Error: No partition with label 'home' found."
    exit 1
fi

# Append the entry to /etc/fstab (adjust the mount point and file system type as needed)
echo "UUID=$UUID  /home	btrfs		defaults,noatime,autodefrag,compress=zstd 0 0" | sudo tee -a /etc/fstab

echo "Entry for 'home' added to /etc/fstab."




# Auto create FSTAB for games or steam labeled partition
UUID=$(lsblk -o UUID,LABEL | grep -E 'games|steam' | awk '{print $1}')

# Check if UUID was found
if [ -z "$UUID" ]; then
    echo "Error: No partition with label 'games' or 'steam' found."
    exit 1
fi

# Append the entry to /etc/fstab (adjust the mount point and file system type as needed)
echo "UUID=$UUID  /games  ntfs-3g  defaults,locale=en_US.UTF-8,uid=1000,gid=1000,umask=0022 0 2" | sudo tee -a /etc/fstab

echo "Entry for 'games' or 'steam' added to /etc/fstab."
