#!/usr/bin/env bash

# Semi-automated NixOS installation WITHOUT disk encryption
# Safer alternative with checks at each step

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
echo "Semi-Automated NixOS Installation WITHOUT encryption"
echo "Simple and reliable installation without LUKS complexity"
echo "================================================================"
echo

warning "WARNING: This version does NOT use disk encryption!"
warning "Data will be stored unencrypted."
echo

# Step 1: Network check
info "Step 1/7: Network check"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    success "Internet connected"
else
    error "Configure internet and try again"
fi
pause

# Step 2: Disk selection
info "Step 2/7: Disk selection for installation"
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
warning "Data will NOT be encrypted!"
lsblk "$DISK"
echo
read -p "Confirm disk selection $DISK (type 'confirm'): " CONFIRM
if [ "$CONFIRM" != "confirm" ]; then
    error "Installation cancelled"
fi
pause

# Step 3: Disk partitioning
info "Step 3/7: Disk partitioning WITHOUT encryption"
echo "Will create the following layout:"
echo "• EFI Boot: 512MB"
echo "• LVM partition: remaining space (WITHOUT LUKS encryption)"
echo "  ├── Root: 60GB (ext4)"
echo "  ├── Home: ~400GB (ext4)" 
echo "  └── Swap: 32GB (for hibernation)"
echo

pause

# Wipe and partition
wipefs -a "$DISK"
(
echo g # GPT
echo n; echo 1; echo; echo +512M  # EFI
echo n; echo 2; echo; echo        # LVM  
echo t; echo 1; echo 1            # EFI type
echo w
) | fdisk "$DISK"

# Wait for partition table update
partprobe "$DISK" || true
sleep 3

# Determine partitions
if [[ "$DISK" =~ nvme ]]; then
    EFI="${DISK}p1"
    LVM="${DISK}p2"
else
    EFI="${DISK}1" 
    LVM="${DISK}2"
fi

# Check that partitions were created
if [ ! -b "$EFI" ] || [ ! -b "$LVM" ]; then
    error "Partitions were not created correctly"
fi

success "Disk partitioned: EFI=$EFI, LVM=$LVM"
pause

# Step 4: Create filesystems WITHOUT encryption
info "Step 4/7: Creating filesystems WITHOUT encryption"

# EFI
mkfs.fat -F 32 -n BOOT "$EFI"

# LVM WITHOUT LUKS
info "Creating LVM directly on partition (without LUKS)..."
pvcreate "$LVM"
vgcreate vg0 "$LVM"
lvcreate -L 32G -n swap vg0
lvcreate -L 60G -n root vg0  
lvcreate -l 100%FREE -n home vg0

# Format with forced overwrite
mkfs.ext4 -F -L NIXOS /dev/vg0/root
mkfs.ext4 -F -L HOME /dev/vg0/home
mkswap -f -L SWAP /dev/vg0/swap

success "Filesystems created WITHOUT encryption"
lvdisplay
pause

# Step 5: Mount filesystems
info "Step 5/7: Mounting filesystems"

mount /dev/vg0/root /mnt
mkdir -p /mnt/boot /mnt/home
mount "$EFI" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

# Check mounting
if ! mountpoint -q /mnt; then
    error "Root filesystem is not mounted"
fi

success "Filesystems mounted"
df -h /mnt*
pause

# Step 6: Generate and copy configuration
info "Step 6/7: NixOS configuration setup WITHOUT LUKS"

# Generate hardware config
nixos-generate-config --root /mnt

echo "Do you want to use the ready optimized configuration?"
echo "1) Yes - create ready flake.nix, configuration.nix, home.nix WITHOUT LUKS"
echo "2) No - edit standard configuration.nix manually"
read -p "Choose (1/2): " CONFIG_CHOICE

case $CONFIG_CHOICE in
    1)
        info "Creating optimized configuration WITHOUT LUKS..."
        
        cd /mnt/etc/nixos
        rm -f configuration.nix
        
        # Create flake.nix
        cat > flake.nix << 'EOF'
{
  description = "Optimized NixOS configuration without LUKS";

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
        cat > configuration.nix << 'EOF'
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

  networking.hostName = "PC-NixOS";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "ru_RU.UTF-8";
  console.keyMap = "us";

  users.users.artfil-nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "bluetooth" ];
  };
  users.mutableUsers = true;
  security.sudo.wheelNeedsPassword = false;

  services.getty.autologinUser = "artfil-nixos";

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
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
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
        cat > home.nix << 'EOF'
{ config, pkgs, inputs, lib, ... }:

let
  username = "artfil-nixos";
in
{
  home-manager.useUserPackages = true;
  home-manager.users.${username} = {
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
        
        success "Optimized configuration WITHOUT LUKS created"
        ;;
    2)
        info "Editing standard configuration..."
        warning "Don't forget to uncomment needed options:"
        echo "• boot.loader.systemd-boot.enable = true;"
        echo "• networking.networkmanager.enable = true;"
        echo "• users.users.yourusername = {...};"
        pause
        nano /mnt/etc/nixos/configuration.nix
        ;;
esac

success "Configuration ready"
pause

# Step 7: Installation
info "Step 7/7: NixOS installation"

cd /mnt/etc/nixos

if [ -f "flake.nix" ]; then
    info "Installing with flake configuration..."
    
    # Check configuration before installation
    if nix flake check --no-build; then
        success "Flake configuration is correct"
    else
        warning "Configuration issues detected, but continuing..."
    fi
    
    nixos-install --flake .#PC-NixOS --no-root-passwd
else
    info "Installing with standard configuration..."
    nixos-install --no-root-passwd
fi

success "NixOS installed successfully WITHOUT encryption!"

echo
echo "================================================================"
echo "Installation completed!"
echo
echo "Installation features:"
echo "• WITHOUT LUKS encryption - simple boot"
echo "• LVM for flexible partition management"
echo "• Hyprland + NVIDIA RTX 4070 optimizations"
echo "• Gaming-ready system"
echo "• Auto-login user"
echo
echo "Next steps:"
echo "1. System will boot automatically WITHOUT passwords"
echo "2. Set user password: passwd artfil-nixos"
echo "3. Enjoy NixOS!"
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

warning "Remove installation media and reboot"
read -p "Reboot now? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi