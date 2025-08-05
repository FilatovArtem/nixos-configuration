#!/usr/bin/env bash

# Автоматизированная установка NixOS с оптимизированной конфигурацией
# Основано на: https://gist.github.com/nuxeh/35fb0eca2af4b305052ca11fe2521159
# Адаптировано для системы: Intel i5-11600 + RTX 4070 + UWQHD

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Проверка что скрипт запущен с правами root
if [ "$EUID" -ne 0 ]; then
    error "Скрипт должен быть запущен с правами root (sudo)"
fi

# Конфигурация по умолчанию
DEFAULT_HOSTNAME="PC-NixOS"
DEFAULT_USERNAME="artfil-nixos"
DEFAULT_TIMEZONE="Europe/Moscow"
DEFAULT_LOCALE="ru_RU.UTF-8"
DEFAULT_KEYMAP="us"

echo "════════════════════════════════════════════════════════════════"
echo "🚀 Автоматизированная установка NixOS"
echo "   Оптимизированная конфигурация для Intel i5-11600 + RTX 4070"
echo "════════════════════════════════════════════════════════════════"
echo

# Проверка сети
info "Проверка подключения к интернету..."
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    error "Нет подключения к интернету. Настройте сеть и повторите."
fi
success "Интернет подключен"

# Показать доступные диски
info "Обнаружены следующие диски:"
echo
sudo fdisk -l | grep "^Disk /dev" | awk '{print $2}' | sed 's/://' | nl -v 0
echo

# Выбор диска
read -p "Укажите номер диска для установки (обычно 0 для NVMe): " DISK_NUM
DEVICES=($(sudo fdisk -l | grep "^Disk /dev" | awk '{print $2}' | sed 's/://'))
DISK="${DEVICES[$DISK_NUM]}"

if [ -z "$DISK" ]; then
    error "Неверный номер диска"
fi

info "Выбран диск: $DISK"

# Параметры установки
read -p "Имя хоста [$DEFAULT_HOSTNAME]: " HOSTNAME
HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}

read -p "Имя пользователя [$DEFAULT_USERNAME]: " USERNAME  
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Размер swap в GB (рекомендуется 32 для гибернации): " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-32}

read -p "Пароль для шифрования диска: " -s LUKS_PASSWORD
echo
read -p "Повторите пароль: " -s LUKS_PASSWORD_CONFIRM
echo

if [ "$LUKS_PASSWORD" != "$LUKS_PASSWORD_CONFIRM" ]; then
    error "Пароли не совпадают"
fi

echo
warning "ВНИМАНИЕ: Диск $DISK будет ПОЛНОСТЬЮ ОЧИЩЕН!"
warning "Все данные будут ПОТЕРЯНЫ!"
echo
read -p "Продолжить? Введите 'YES' для подтверждения: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    error "Установка отменена"
fi

info "Начинаю установку NixOS..."

# Очистка диска
info "Очистка диска $DISK..."
wipefs -a "$DISK" || true
sync

# Создание разделов
info "Создание разделов..."
(
echo g # новая GPT таблица
echo n # новый раздел
echo 1 # номер раздела 1 (EFI)
echo   # начальный сектор по умолчанию
echo +512M # размер 512MB
echo n # новый раздел  
echo 2 # номер раздела 2 (LUKS)
echo   # начальный сектор по умолчанию
echo   # конечный сектор по умолчанию (весь оставшийся диск)
echo t # изменить тип
echo 1 # раздел 1
echo 1 # EFI System
echo w # записать изменения
) | fdisk "$DISK"

# Определение разделов
if [[ "$DISK" =~ nvme ]]; then
    EFI_PARTITION="${DISK}p1"
    LUKS_PARTITION="${DISK}p2"
else
    EFI_PARTITION="${DISK}1"
    LUKS_PARTITION="${DISK}2"
fi

info "EFI раздел: $EFI_PARTITION"
info "LUKS раздел: $LUKS_PARTITION"

# Форматирование EFI раздела
info "Форматирование EFI раздела..."
mkfs.fat -F 32 -n BOOT "$EFI_PARTITION"

# Создание LUKS контейнера
info "Создание LUKS контейнера..."
echo "$LUKS_PASSWORD" | cryptsetup luksFormat "$LUKS_PARTITION" -

# Открытие LUKS контейнера
info "Открытие LUKS контейнера..."
echo "$LUKS_PASSWORD" | cryptsetup luksOpen "$LUKS_PARTITION" nixos-root

# Создание LVM
info "Настройка LVM..."
pvcreate /dev/mapper/nixos-root
vgcreate vg0 /dev/mapper/nixos-root

# Создание логических томов
lvcreate -L "${SWAP_SIZE}G" -n swap vg0
lvcreate -L 60G -n root vg0
lvcreate -l 100%FREE -n home vg0

# Форматирование файловых систем
info "Форматирование файловых систем..."
mkfs.ext4 -L NIXOS /dev/vg0/root
mkfs.ext4 -L HOME /dev/vg0/home
mkswap -L SWAP /dev/vg0/swap

# Монтирование
info "Монтирование файловых систем..."
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/home
mount "$EFI_PARTITION" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

# Генерация конфигурации
info "Генерация hardware-configuration.nix..."
nixos-generate-config --root /mnt

# Скачивание оптимизированной конфигурации
info "Загрузка оптимизированной конфигурации..."
cd /mnt/etc/nixos

# Удаляем стандартный configuration.nix
rm -f configuration.nix

# Создаем flake.nix
cat > flake.nix << 'EOF'
{
  description = "Оптимизированная NixOS конфигурация";

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

# Создаем configuration.nix
cat > configuration.nix << EOF
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  # LUKS настройки (будут обновлены автоматически)
  boot.initrd.luks.devices."nixos-root" = {
    device = "$LUKS_PARTITION";
    preLVM = true;
  };

  # Поддержка гибернации
  boot.resumeDevice = "/dev/vg0/swap";
  boot.kernelParams = [ "resume=/dev/vg0/swap" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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
    package = inputs.hyprland.packages.\${pkgs.system}.hyprland;
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

# Установка NixOS
info "Установка NixOS..."
nixos-install --flake .#PC-NixOS --no-root-passwd

success "Установка завершена успешно!"

echo
echo "════════════════════════════════════════════════════════════════"
echo "🎉 NixOS установлена с оптимизированной конфигурацией!"
echo
echo "📋 Что установлено:"
echo "   • Hyprland compositor"
echo "   • NVIDIA RTX 4070 драйверы"
echo "   • PipeWire с низкой задержкой"
echo "   • Steam и gaming оптимизации"
echo "   • UWQHD монитор поддержка"
echo "   • LUKS шифрование диска"
echo "   • Автологин пользователя $USERNAME"
echo
echo "🔐 При загрузке введите пароль для расшифровки диска"
echo "🎮 Система готова для gaming и высокопроизводительных задач"
echo
echo "════════════════════════════════════════════════════════════════"

# Очистка
info "Размонтирование файловых систем..."
umount -R /mnt || true
swapoff /dev/vg0/swap || true
vgchange -a n vg0 || true
cryptsetup luksClose nixos-root || true

warning "Извлеките установочный носитель и перезагрузите систему"
read -p "Нажмите Enter для перезагрузки..." 

reboot