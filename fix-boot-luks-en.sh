#!/usr/bin/env bash

# Script to fix NixOS boot issues with LUKS after installation
# Use after booting from live USB

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}INFO: $1${NC}"; }
success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
error() { echo -e "${RED}ERROR: $1${NC}"; }

if [ "$EUID" -ne 0 ]; then
    error "Run with sudo"
    exit 1
fi

echo "================================================================"
echo "🔧 Fix NixOS Boot Issues with LUKS"
echo "================================================================"
echo

# Step 1: Find LUKS partition
info "Step 1: Finding LUKS partitions"
echo "Available disks:"
lsblk
echo

echo "Searching for LUKS partitions..."
LUKS_PARTITIONS=$(blkid | grep "TYPE=\"crypto_LUKS\"" | cut -d: -f1 || true)

if [ -z "$LUKS_PARTITIONS" ]; then
    error "No LUKS partitions found! Check your installation."
    exit 1
fi

echo "Found LUKS partitions:"
echo "$LUKS_PARTITIONS"
echo

# Select LUKS partition
if [ $(echo "$LUKS_PARTITIONS" | wc -l) -eq 1 ]; then
    LUKS_DEVICE="$LUKS_PARTITIONS"
    info "Automatically selected: $LUKS_DEVICE"
else
    echo "Select LUKS partition:"
    echo "$LUKS_PARTITIONS" | nl
    read -p "Enter number: " NUM
    LUKS_DEVICE=$(echo "$LUKS_PARTITIONS" | sed -n "${NUM}p")
fi

if [ -z "$LUKS_DEVICE" ]; then
    error "LUKS device not selected"
    exit 1
fi

info "Using LUKS device: $LUKS_DEVICE"

# Step 2: Open LUKS and mount
info "Step 2: Opening LUKS container"
echo "Enter password to decrypt disk:"

if ! cryptsetup luksOpen "$LUKS_DEVICE" nixos-root; then
    error "Failed to open LUKS container. Check password."
    exit 1
fi

success "LUKS container opened"

# Activate LVM
info "Activating LVM..."
vgchange -ay || true

# Check LVM volumes
if [ ! -b "/dev/vg0/root" ]; then
    error "LVM volume /dev/vg0/root not found"
    lvs
    exit 1
fi

# Mount filesystems
info "Step 3: Mounting filesystems"

mount /dev/vg0/root /mnt

# Find EFI partition
EFI_PARTITION=""
for part in /dev/nvme0n1p1 /dev/sda1 /dev/vda1; do
    if [ -b "$part" ] && file -s "$part" | grep -q "FAT"; then
        EFI_PARTITION="$part"
        break
    fi
done

if [ -z "$EFI_PARTITION" ]; then
    warning "EFI partition not found automatically"
    lsblk
    read -p "Enter EFI partition (e.g. /dev/nvme0n1p1): " EFI_PARTITION
fi

mkdir -p /mnt/boot
mount "$EFI_PARTITION" /mnt/boot

if [ -b "/dev/vg0/home" ]; then
    mkdir -p /mnt/home
    mount /dev/vg0/home /mnt/home
fi

success "Filesystems mounted"

# Step 4: Check and fix configuration
info "Step 4: Checking NixOS configuration"

if [ ! -f "/mnt/etc/nixos/configuration.nix" ]; then
    error "NixOS configuration not found in /mnt/etc/nixos/"
    exit 1
fi

info "Current LUKS configuration:"
grep -A 5 "boot.initrd.luks.devices" /mnt/etc/nixos/configuration.nix || echo "LUKS configuration not found!"

echo
warning "Checking LUKS device correctness in configuration..."

# Get LUKS device UUID
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_DEVICE")
info "LUKS device UUID: $LUKS_UUID"

# Check configuration
if grep -q "boot.initrd.luks.devices" /mnt/etc/nixos/configuration.nix; then
    if grep -q "$LUKS_DEVICE\|$LUKS_UUID" /mnt/etc/nixos/configuration.nix; then
        success "LUKS device correctly configured"
    else
        warning "LUKS device in configuration doesn't match actual device!"
        echo "Fixing configuration..."
        
        # Create backup
        cp /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.backup
        
        # Fix device
        sed -i "s|device = \".*\";|device = \"$LUKS_DEVICE\";|" /mnt/etc/nixos/configuration.nix
        success "Configuration fixed"
    fi
else
    error "LUKS configuration missing from configuration.nix!"
    echo "Adding LUKS configuration..."
    
    # Find imports line and add LUKS configuration after it
    sed -i '/imports = \[/a\\n  # LUKS configuration\n  boot.initrd.luks.devices."nixos-root" = {\n    device = "'$LUKS_DEVICE'";\n    preLVM = true;\n  };' /mnt/etc/nixos/configuration.nix
    
    success "LUKS configuration added"
fi

# Step 5: Check and add required kernel modules
info "Step 5: Checking kernel modules"

if ! grep -q "boot.initrd.kernelModules" /mnt/etc/nixos/configuration.nix; then
    info "Adding required kernel modules..."
    sed -i '/boot.initrd.luks.devices/a\\n  # Required kernel modules for LUKS + LVM\n  boot.initrd.kernelModules = [ "dm-crypt" "dm-mod" "dm-snapshot" "dm-raid" ];' /mnt/etc/nixos/configuration.nix
fi

# Step 6: Rebuild system
info "Step 6: Rebuilding bootloader"

cd /mnt/etc/nixos

# Check if flake exists
if [ -f "flake.nix" ]; then
    info "Rebuilding with flake configuration..."
    nixos-install --root /mnt --flake .#PC-NixOS --no-root-passwd
else
    info "Rebuilding with standard configuration..."
    nixos-install --root /mnt --no-root-passwd
fi

success "System rebuilt"

echo
echo "================================================================"
echo "✅ Fix completed!"
echo
echo "📋 What was fixed:"
echo "• Checked and fixed LUKS configuration"
echo "• Added required kernel modules"  
echo "• Rebuilt initrd with correct settings"
echo
echo "🔄 Next steps:"
echo "1. Remove live USB"
echo "2. Reboot system"
echo "3. Enter LUKS password during boot"
echo "4. System should boot normally"
echo "================================================================"

# Unmount
info "Unmounting filesystems..."
umount -R /mnt || true
vgchange -a n vg0 || true
cryptsetup luksClose nixos-root || true

warning "Reboot system and check boot"
read -p "Reboot now? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi