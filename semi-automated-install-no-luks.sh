#!/usr/bin/env bash

# Полуавтоматическая установка NixOS БЕЗ шифрования диска
# Более безопасная альтернатива с проверками на каждом этапе

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

pause() {
    read -p "Нажмите Enter для продолжения или Ctrl+C для выхода..."
}

if [ "$EUID" -ne 0 ]; then
    error "Запустите с sudo"
fi

echo "════════════════════════════════════════════════════════════════"
echo "🔧 Полуавтоматическая установка NixOS БЕЗ шифрования"
echo "   Простая и надежная установка без сложностей с LUKS"
echo "════════════════════════════════════════════════════════════════"
echo

warning "ВНИМАНИЕ: Эта версия НЕ использует шифрование диска!"
warning "Данные будут храниться в открытом виде."
echo

# Этап 1: Проверка сети
info "Этап 1/7: Проверка сети"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    success "Интернет подключен"
else
    error "Настройте интернет и повторите"
fi
pause

# Этап 2: Выбор диска
info "Этап 2/7: Выбор диска для установки"
echo
lsblk
echo
warning "Выберите диск для установки NixOS"
echo "Пример: /dev/nvme0n1 для NVMe SSD"
read -p "Введите устройство (например /dev/nvme0n1): " DISK

if [ ! -b "$DISK" ]; then
    error "Устройство $DISK не найдено"
fi

echo
warning "ВНИМАНИЕ: Диск $DISK будет полностью очищен!"
warning "Данные НЕ будут зашифрованы!"
lsblk "$DISK"
echo
read -p "Подтвердите выбор диска $DISK (введите 'confirm'): " CONFIRM
if [ "$CONFIRM" != "confirm" ]; then
    error "Установка отменена"
fi
pause

# Этап 3: Разметка диска
info "Этап 3/7: Разметка диска БЕЗ шифрования"
echo "Будет создана следующая разметка:"
echo "• EFI Boot: 512MB"
echo "• LVM раздел: остальное место (БЕЗ LUKS шифрования)"
echo "  ├── Root: 60GB (ext4)"
echo "  ├── Home: ~400GB (ext4)" 
echo "  └── Swap: 32GB (для гибернации)"
echo

pause

# Очистка и разметка
wipefs -a "$DISK"
(
echo g # GPT
echo n; echo 1; echo; echo +512M  # EFI
echo n; echo 2; echo; echo        # LVM  
echo t; echo 1; echo 1            # EFI type
echo w
) | fdisk "$DISK"

# Ждем обновления таблицы разделов
partprobe "$DISK" || true
sleep 3

# Определение разделов
if [[ "$DISK" =~ nvme ]]; then
    EFI="${DISK}p1"
    LVM="${DISK}p2"
else
    EFI="${DISK}1" 
    LVM="${DISK}2"
fi

# Проверка что разделы созданы
if [ ! -b "$EFI" ] || [ ! -b "$LVM" ]; then
    error "Разделы не были созданы корректно"
fi

success "Диск размечен: EFI=$EFI, LVM=$LVM"
pause

# Этап 4: Создание файловых систем БЕЗ шифрования
info "Этап 4/7: Создание файловых систем БЕЗ шифрования"

# EFI
mkfs.fat -F 32 -n BOOT "$EFI"

# LVM БЕЗ LUKS
info "Создание LVM напрямую на разделе (без LUKS)..."
pvcreate "$LVM"
vgcreate vg0 "$LVM"
lvcreate -L 32G -n swap vg0
lvcreate -L 60G -n root vg0  
lvcreate -l 100%FREE -n home vg0

# Форматирование с принудительной перезаписью
mkfs.ext4 -F -L NIXOS /dev/vg0/root
mkfs.ext4 -F -L HOME /dev/vg0/home
mkswap -f -L SWAP /dev/vg0/swap

success "Файловые системы созданы БЕЗ шифрования"
lvdisplay
pause

# Этап 5: Монтирование
info "Этап 5/7: Монтирование файловых систем"

mount /dev/vg0/root /mnt
mkdir -p /mnt/boot /mnt/home
mount "$EFI" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

# Проверяем монтирование
if ! mountpoint -q /mnt; then
    error "Корневая файловая система не смонтирована"
fi

success "Файловые системы смонтированы"
df -h /mnt*
pause

# Этап 6: Генерация и копирование конфигурации
info "Этап 6/7: Настройка конфигурации NixOS БЕЗ LUKS"

# Генерируем hardware config
nixos-generate-config --root /mnt

echo "Хотите использовать готовую оптимизированную конфигурацию?"
echo "1) Да - скопировать готовые файлы flake.nix, configuration.nix, home.nix БЕЗ LUKS"
echo "2) Нет - редактировать стандартную configuration.nix вручную"
read -p "Выберите (1/2): " CONFIG_CHOICE

case $CONFIG_CHOICE in
    1)
        info "Создание оптимизированной конфигурации БЕЗ LUKS..."
        
        cd /mnt/etc/nixos
        rm -f configuration.nix
        
        # Создаем flake.nix
        cat > flake.nix << 'EOF'
{
  description = "Оптимизированная NixOS конфигурация без LUKS";

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

        # Создаем configuration.nix БЕЗ LUKS
        cat > configuration.nix << 'EOF'
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # Простая загрузка БЕЗ LUKS
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Поддержка гибернации
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

  # NVIDIA настройки для RTX 4070
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

  # Системные пакеты
  environment.systemPackages = with pkgs; [
    kitty neovim firefox waybar wofi kanshi git
    fastfetch btop ripgrep fzf eza bat yazi
    grim slurp wl-clipboard
    steam
  ];

  # Аудио с низкой задержкой
  sound.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    socketActivation = true;
    
    # Низкая задержка для gaming
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

  # Gaming оптимизации
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # NVIDIA переменные окружения
  environment.variables = {
    NIXOS_OZONE_WL = "1";
    __GL_THREADED_OPTIMIZATIONS = "1";
    VDPAU_DRIVER = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  };

  # Шрифты для UWQHD
  fonts.packages = with pkgs; [
    fira-code
    jetbrains-mono
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; })
    font-awesome
  ];

  system.stateVersion = "24.05";
}
EOF

        # Создаем home.nix
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
        
        success "Оптимизированная конфигурация БЕЗ LUKS создана"
        ;;
    2)
        info "Редактирование стандартной конфигурации..."
        warning "Не забудьте раскомментировать нужные опции:"
        echo "• boot.loader.systemd-boot.enable = true;"
        echo "• networking.networkmanager.enable = true;"
        echo "• users.users.yourusername = {...};"
        pause
        nano /mnt/etc/nixos/configuration.nix
        ;;
esac

success "Конфигурация подготовлена"
pause

# Этап 7: Установка
info "Этап 7/7: Установка NixOS"

cd /mnt/etc/nixos

if [ -f "flake.nix" ]; then
    info "Установка с flake конфигурацией..."
    
    # Проверяем конфигурацию перед установкой
    if nix flake check --no-build; then
        success "Конфигурация flake корректна"
    else
        warning "Обнаружены проблемы в конфигурации, но продолжаем..."
    fi
    
    nixos-install --flake .#PC-NixOS --no-root-passwd
else
    info "Установка со стандартной конфигурацией..."
    nixos-install --no-root-passwd
fi

success "🎉 NixOS установлена успешно БЕЗ шифрования!"

echo
echo "════════════════════════════════════════════════════════════════"
echo "✅ Установка завершена!"
echo
echo "📋 Особенности установки:"
echo "• БЕЗ LUKS шифрования - простая загрузка"
echo "• LVM для гибкого управления разделами"
echo "• Hyprland + NVIDIA RTX 4070 оптимизации"
echo "• Gaming готовая система"
echo "• Автологин пользователя"
echo
echo "🔄 Следующие шаги:"
echo "1. Система загрузится автоматически БЕЗ паролей"
echo "2. Установите пароль пользователя: passwd artfil-nixos"
echo "3. Наслаждайтесь NixOS!"
echo
echo "🔧 Полезные команды:"
echo "• nixos-rebuild switch  - применить изменения конфигурации"
echo "• nix-collect-garbage -d - очистить старые поколения"
echo "• fastfetch - информация о системе"
echo "════════════════════════════════════════════════════════════════"

# Очистка
info "Размонтирование..."
umount -R /mnt
swapoff /dev/vg0/swap
vgchange -a n vg0

warning "Извлеките установочный носитель и перезагрузитесь"
read -p "Перезагрузить сейчас? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi