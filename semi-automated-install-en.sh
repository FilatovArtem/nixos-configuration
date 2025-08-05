#!/usr/bin/env bash

# Semi-automated NixOS installation with safety checks at each step
# Safer alternative to fully automated installation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}INFO: $1${NC}"; }
success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
error() { echo -e "${RED}ERROR: $1${NC}"; exit 1; }

pause() {
    read -p "Press Enter to continue or Ctrl+C to exit..."
}

if [ "$EUID" -ne 0 ]; then
    error "Run with sudo"
fi

echo "================================================================"
echo "Semi-Automated NixOS Installation"
echo "With safety checks at each step"
echo "================================================================"
echo

# Step 1: Network check
info "Step 1/8: Network check"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    success "Internet connected"
else
    error "Configure internet and try again"
fi
pause

# Step 2: Disk selection
info "Step 2/8: Disk selection for installation"
echo
lsblk
echo
warning "Choose disk for NixOS installation"
echo "Example: /dev/nvme0n1 for NVMe SSD"
read -p "Enter device (e.g. /dev/nvme0n1): " DISK

if [ ! -b "$DISK" ]; then
    error "Device $DISK not found"
fi

echo
warning "WARNING: Disk $DISK will be completely wiped!"
lsblk "$DISK"
echo
read -p "Confirm disk selection $DISK (type 'confirm'): " CONFIRM
if [ "$CONFIRM" != "confirm" ]; then
    error "Installation cancelled"
fi
pause

# Step 3: Disk partitioning
info "Step 3/8: Disk partitioning"
echo "Will create the following layout:"
echo "• EFI Boot: 512MB"
echo "• LUKS container: remaining space"
echo "  ├── Root: 60GB (ext4)"
echo "  ├── Home: ~400GB (ext4)" 
echo "  └── Swap: 32GB (for hibernation)"
echo

pause

wipefs -a "$DISK"
(
echo g # GPT
echo n; echo 1; echo; echo +512M  # EFI
echo n; echo 2; echo; echo        # LUKS  
echo t; echo 1; echo 1            # EFI type
echo w
) | fdisk "$DISK"

# Determine partitions
if [[ "$DISK" =~ nvme ]]; then
    EFI="${DISK}p1"
    LUKS="${DISK}p2"
else
    EFI="${DISK}1" 
    LUKS="${DISK}2"
fi

success "Disk partitioned: EFI=$EFI, LUKS=$LUKS"
pause

# Step 4: LUKS encryption setup
info "Step 4/8: LUKS encryption setup"
warning "Create a STRONG password for disk encryption"
echo

cryptsetup luksFormat "$LUKS"
cryptsetup luksOpen "$LUKS" nixos-root

success "LUKS container created and opened"
pause

# Step 5: Create filesystems
info "Step 5/8: Creating filesystems"

# EFI
mkfs.fat -F 32 -n BOOT "$EFI"

# LVM
pvcreate /dev/mapper/nixos-root
vgcreate vg0 /dev/mapper/nixos-root
lvcreate -L 32G -n swap vg0
lvcreate -L 60G -n root vg0  
lvcreate -l 100%FREE -n home vg0

# Format filesystems
mkfs.ext4 -L NIXOS /dev/vg0/root
mkfs.ext4 -L HOME /dev/vg0/home
mkswap -L SWAP /dev/vg0/swap

success "Filesystems created"
lvdisplay
pause

# Step 6: Mount filesystems
info "Step 6/8: Mounting filesystems"

mount /dev/vg0/root /mnt
mkdir -p /mnt/boot /mnt/home
mount "$EFI" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

success "Filesystems mounted"
df -h /mnt*
pause

# Step 7: Generate and copy configuration
info "Step 7/8: NixOS configuration setup"

# Generate hardware config
nixos-generate-config --root /mnt

echo "Do you want to use the ready optimized configuration?"
echo "1) Yes - copy ready flake.nix, configuration.nix, home.nix files"
echo "2) No - edit standard configuration.nix manually"
read -p "Choose (1/2): " CONFIG_CHOICE

case $CONFIG_CHOICE in
    1)
        info "Copying optimized configuration..."
        
        # Determine source files path
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        if [ -f "$SCRIPT_DIR/flake.nix" ]; then
            cp "$SCRIPT_DIR/flake.nix" /mnt/etc/nixos/
            cp "$SCRIPT_DIR/configuration.nix" /mnt/etc/nixos/
            cp "$SCRIPT_DIR/home.nix" /mnt/etc/nixos/
            
            # Update LUKS device in configuration
            sed -i "s|device = \".*\";|device = \"$LUKS\";|" /mnt/etc/nixos/configuration.nix
            
            success "Optimized configuration copied"
        else
            warning "Configuration files not found in current directory"
            warning "Using standard configuration"
            nano /mnt/etc/nixos/configuration.nix
        fi
        ;;
    2)
        info "Editing standard configuration..."
        warning "Don't forget to uncomment needed options:"
        echo "• boot.loader.systemd-boot.enable = true;"
        echo "• networking.networkmanager.enable = true;"
        echo "• users.users.yourusername = {...};"
        echo "• services.xserver.enable = true; (if needed)"
        pause
        nano /mnt/etc/nixos/configuration.nix
        ;;
esac

success "Configuration ready"
pause

# Step 8: Installation
info "Step 8/8: NixOS installation"

if [ -f "/mnt/etc/nixos/flake.nix" ]; then
    info "Installing with flake configuration..."
    cd /mnt/etc/nixos
    nixos-install --flake .#PC-NixOS --no-root-passwd
else
    info "Installing with standard configuration..."
    nixos-install --no-root-passwd
fi

success "NixOS installed successfully!"

echo
echo "================================================================"
echo "Installation completed!"
echo
echo "Next steps:"
echo "1. Set user password after first boot"  
echo "2. Enter LUKS password during boot to decrypt disk"
echo "3. System will automatically log in"
echo
echo "Useful commands:"
echo "• nixos-rebuild switch  - apply configuration changes"
echo "• nix-collect-garbage -d - clean old generations"
echo "• fastfetch - system information"
echo "================================================================"

# Cleanup
info "Unmounting..."
umount -R /mnt
swapoff /dev/vg0/swap
vgchange -a n vg0
cryptsetup luksClose nixos-root

warning "Remove installation media and reboot"
read -p "Reboot now? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi