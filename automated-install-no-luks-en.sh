#!/usr/bin/env bash

# Automated NixOS Installation WITHOUT disk encryption
# Simple and reliable installation for beginners

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Colored output functions
info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (sudo)"
fi

# Default configuration
DEFAULT_HOSTNAME="PC-NixOS"
DEFAULT_USERNAME="artfil-nixos"
DEFAULT_TIMEZONE="Europe/Moscow"
DEFAULT_LOCALE="ru_RU.UTF-8"
DEFAULT_KEYMAP="us"

echo "================================================================"
echo "Automated NixOS Installation WITHOUT encryption"
echo "Simple and reliable installation for beginners"
echo "Optimized for Intel i5-11600 + RTX 4070"
echo "================================================================"
echo

warning "WARNING: This version does NOT use disk encryption!"
warning "Data will be stored unencrypted."
echo

# Check internet connection
info "Checking internet connection..."
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    error "No internet connection. Configure network and try again."
fi
success "Internet connected"

# Show available disks
info "Available storage devices:"
echo
sudo fdisk -l | grep "^Disk /dev" | awk '{print $2}' | sed 's/://' | nl -v 0
echo

# Select disk
read -p "Enter disk number for installation (usually 0 for NVMe): " DISK_NUM
DEVICES=($(sudo fdisk -l | grep "^Disk /dev" | awk '{print $2}' | sed 's/://'))
DISK="${DEVICES[$DISK_NUM]}"

if [ -z "$DISK" ]; then
    error "Invalid disk number"
fi

info "Selected disk: $DISK"

# Installation parameters
read -p "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Username [$DEFAULT_USERNAME]: " USERNAME  
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Swap size in GB (recommended 32 for hibernation): " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-32}

echo
warning "WARNING: Disk $DISK will be COMPLETELY WIPED!"
warning "All data will be LOST!"
warning "Data will NOT be encrypted!"
echo
read -p "Continue? Type 'YES' to confirm: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    error "Installation cancelled"
fi

info "Starting NixOS installation..."

# Wipe disk
info "Wiping disk $DISK..."
wipefs -a "$DISK" || true
sync
sleep 2

# Create partitions WITHOUT LUKS
info "Creating partitions without encryption..."
(
echo g # new GPT table
echo n # new partition
echo 1 # partition number 1 (EFI)
echo   # default start sector
echo +512M # size 512MB
echo n # new partition  
echo 2 # partition number 2 (LVM)
echo   # default start sector
echo   # default end sector (rest of disk)
echo t # change type
echo 1 # partition 1
echo 1 # EFI System
echo w # write changes
) | fdisk "$DISK"

# Wait for partition table update
partprobe "$DISK" || true
sleep 3

# Determine partition names
if [[ "$DISK" =~ nvme ]]; then
    EFI_PARTITION="${DISK}p1"
    LVM_PARTITION="${DISK}p2"
else
    EFI_PARTITION="${DISK}1"
    LVM_PARTITION="${DISK}2"
fi

info "EFI partition: $EFI_PARTITION"
info "LVM partition: $LVM_PARTITION"

# Check that partitions were created
if [ ! -b "$EFI_PARTITION" ] || [ ! -b "$LVM_PARTITION" ]; then
    error "Partitions were not created correctly. Check disk $DISK"
fi

# Format EFI partition
info "Formatting EFI partition..."
mkfs.fat -F 32 -n BOOT "$EFI_PARTITION"

# Create LVM WITHOUT LUKS
info "Setting up LVM without encryption..."
pvcreate "$LVM_PARTITION"
vgcreate vg0 "$LVM_PARTITION"

# Create logical volumes
lvcreate -L "${SWAP_SIZE}G" -n swap vg0
lvcreate -L 60G -n root vg0
lvcreate -l 100%FREE -n home vg0

# Check that LVM volumes were created
if [ ! -b "/dev/vg0/root" ] || [ ! -b "/dev/vg0/home" ] || [ ! -b "/dev/vg0/swap" ]; then
    error "LVM volumes were not created correctly"
fi

success "LVM volumes created"

# Format filesystems
info "Formatting filesystems..."
mkfs.ext4 -F -L NIXOS /dev/vg0/root
mkfs.ext4 -F -L HOME /dev/vg0/home
mkswap -f -L SWAP /dev/vg0/swap

# Mount filesystems
info "Mounting filesystems..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/home
mount "$EFI_PARTITION" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

# Check mounting
if ! mountpoint -q /mnt; then
    error "Root filesystem is not mounted"
fi

success "Filesystems mounted"

# Generate configuration
info "Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt

# Create optimized configuration WITHOUT LUKS
info "Creating optimized configuration without encryption..."
cd /mnt/etc/nixos

# Remove default configuration.nix
rm -f configuration.nix

# Create flake.nix
cat > flake.nix << 'EOF'
{
  description = "Optimized NixOS configuration without encryption";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = inputs@{ self, nixpkgs, home-manager, hyprland, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.PC-NixOS = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ./configuration.nix
          ./home.nix
          home-manager.nixosModules.default
        ];

        specialArgs = {
          inherit inputs;
          hyprland = hyprland.packages.${system}.hyprland;
          portal = hyprland.packages.${system}.xdg-desktop-portal-hyprland;
        };
      };
    };
}
EOF

# Create configuration.nix WITHOUT LUKS
cat > configuration.nix << EOF
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # Simple boot WITHOUT LUKS
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hibernation support
  boot.resumeDevice = "/dev/vg0/swap";
  boot.kernelParams = [ "resume=/dev/vg0/swap" ];

  networking.hostName = "$HOSTNAME";
  networking.networkmanager.enable = true;

  time.timeZone = "$DEFAULT_TIMEZONE";
  i18n.defaultLocale = "$DEFAULT_LOCALE";
  console.keyMap = "$DEFAULT_KEYMAP";

  users.users.$USERNAME = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "bluetooth" ];
  };
  users.mutableUsers = true;
  security.sudo.wheelNeedsPassword = false;

  services.getty.autologinUser = "$USERNAME";

  # NVIDIA settings for RTX 4070
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
  };
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.\${pkgs.system}.hyprland;
  };

  # System packages
  environment.systemPackages = with pkgs; [
    kitty neovim firefox waybar wofi kanshi git
    fastfetch btop ripgrep fzf eza bat yazi
    grim slurp wl-clipboard
    steam
  ];

  # Audio with low latency
  sound.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    socketActivation = true;
    
    # Low latency for gaming
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 32;
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 32;
      };
    };
  };
  security.rtkit.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Gaming optimizations
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # NVIDIA environment variables
  environment.variables = {
    NIXOS_OZONE_WL = "1";
    __GL_THREADED_OPTIMIZATIONS = "1";
    VDPAU_DRIVER = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };

  # Fonts for UWQHD
  fonts.packages = with pkgs; [
    fira-code
    jetbrains-mono
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    font-awesome
  ];

  system.stateVersion = "24.05";
}
EOF

# Create home.nix
cat > home.nix << EOF
{ config, pkgs, inputs, lib, ... }:

let
  username = "$USERNAME";
in
{
  home-manager.useUserPackages = true;
  home-manager.users.\${username} = {
    home.stateVersion = "24.05";

    programs.zsh.enable = true;
    programs.git = {
      enable = true;
      userName = "NixOS User";
      userEmail = "user@nixos.local";
    };

    home.packages = with pkgs; [
      telegram-desktop
      discord
      vlc
      gimp
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        monitor = "DP-1,3440x1440@175,0x0,1";
        
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
        };
        
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
        };

        input = {
          kb_layout = "us,ru";
          kb_options = "grp:alt_shift_toggle";
        };

        bind = [
          "SUPER, Q, exec, kitty"
          "SUPER, C, killactive"
          "SUPER, M, exit"
          "SUPER, R, exec, wofi --show drun"
          "SUPER, V, togglefloating"
          "SUPER, 1, workspace, 1"
          "SUPER, 2, workspace, 2"
          "SUPER, 3, workspace, 3"
          "SUPER, 4, workspace, 4"
          "SUPER, 5, workspace, 5"
          "SUPER SHIFT, 1, movetoworkspace, 1"
          "SUPER SHIFT, 2, movetoworkspace, 2"
          "SUPER SHIFT, 3, movetoworkspace, 3"
          "SUPER SHIFT, 4, movetoworkspace, 4"
          "SUPER SHIFT, 5, movetoworkspace, 5"
        ];
      };
    };
  };
}
EOF

# Test configuration before installation
info "Checking configuration before installation..."
if ! nix flake check --no-build; then
    warning "Configuration issues detected, but continuing installation..."
fi

# Install NixOS
info "Installing NixOS..."
info "This may take 20-30 minutes depending on internet speed..."

if ! nixos-install --flake .#PC-NixOS --no-root-passwd; then
    error "NixOS installation failed"
fi

success "Installation completed successfully!"

echo
echo "================================================================"
echo "NixOS installed WITHOUT encryption!"
echo
echo "What's installed:"
echo "   • Hyprland compositor"
echo "   • NVIDIA RTX 4070 drivers"
echo "   • PipeWire with low latency"
echo "   • Steam and gaming optimizations"
echo "   • UWQHD monitor support"
echo "   • LVM without LUKS (unencrypted)"
echo "   • Auto-login for user $USERNAME"
echo
echo "Simple boot - no password prompts!"
echo "System ready for gaming and high-performance tasks"
echo
echo "================================================================"

# Cleanup
info "Unmounting filesystems..."
umount -R /mnt || true
swapoff /dev/vg0/swap || true
vgchange -a n vg0 || true

warning "Remove installation media and reboot"
read -p "Press Enter to reboot..." 

reboot