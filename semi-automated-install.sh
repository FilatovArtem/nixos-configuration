#!/usr/bin/env bash

# Полуавтоматическая установка NixOS с проверками на каждом этапе
# Более безопасная альтернатива полностью автоматической установке

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
echo "🔧 Полуавтоматическая установка NixOS"
echo "   С проверками безопасности на каждом этапе"
echo "════════════════════════════════════════════════════════════════"
echo

# Этап 1: Проверка сети
info "Этап 1/8: Проверка сети"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    success "Интернет подключен"
else
    error "Настройте интернет и повторите"
fi
pause

# Этап 2: Выбор диска
info "Этап 2/8: Выбор диска для установки"
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
lsblk "$DISK"
echo
read -p "Подтвердите выбор диска $DISK (введите 'confirm'): " CONFIRM
if [ "$CONFIRM" != "confirm" ]; then
    error "Установка отменена"
fi
pause

# Этап 3: Разметка диска
info "Этап 3/8: Разметка диска"
echo "Будет создана следующая разметка:"
echo "• EFI Boot: 512MB"
echo "• LUKS контейнер: остальное место"
echo "  ├── Root: 60GB (ext4)"
echo "  ├── Home: ~400GB (ext4)" 
echo "  └── Swap: 32GB (для гибернации)"
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

# Определение разделов
if [[ "$DISK" =~ nvme ]]; then
    EFI="${DISK}p1"
    LUKS="${DISK}p2"
else
    EFI="${DISK}1" 
    LUKS="${DISK}2"
fi

success "Диск размечен: EFI=$EFI, LUKS=$LUKS"
pause

# Этап 4: Настройка шифрования
info "Этап 4/8: Настройка LUKS шифрования"
warning "Придумайте НАДЕЖНЫЙ пароль для шифрования диска"
echo

cryptsetup luksFormat "$LUKS"
cryptsetup luksOpen "$LUKS" nixos-root

success "LUKS контейнер создан и открыт"
pause

# Этап 5: Создание файловых систем
info "Этап 5/8: Создание файловых систем"

# EFI
mkfs.fat -F 32 -n BOOT "$EFI"

# LVM
pvcreate /dev/mapper/nixos-root
vgcreate vg0 /dev/mapper/nixos-root
lvcreate -L 32G -n swap vg0
lvcreate -L 60G -n root vg0  
lvcreate -l 100%FREE -n home vg0

# Форматирование
mkfs.ext4 -L NIXOS /dev/vg0/root
mkfs.ext4 -L HOME /dev/vg0/home
mkswap -L SWAP /dev/vg0/swap

success "Файловые системы созданы"
lvdisplay
pause

# Этап 6: Монтирование
info "Этап 6/8: Монтирование файловых систем"

mount /dev/vg0/root /mnt
mkdir -p /mnt/boot /mnt/home
mount "$EFI" /mnt/boot
mount /dev/vg0/home /mnt/home
swapon /dev/vg0/swap

success "Файловые системы смонтированы"
df -h /mnt*
pause

# Этап 7: Генерация и копирование конфигурации
info "Этап 7/8: Настройка конфигурации NixOS"

# Генерируем hardware config
nixos-generate-config --root /mnt

echo "Хотите использовать готовую оптимизированную конфигурацию?"
echo "1) Да - скопировать готовые файлы flake.nix, configuration.nix, home.nix"
echo "2) Нет - редактировать стандартную configuration.nix вручную"
read -p "Выберите (1/2): " CONFIG_CHOICE

case $CONFIG_CHOICE in
    1)
        info "Копирование оптимизированной конфигурации..."
        
        # Определяем путь к исходным файлам
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        if [ -f "$SCRIPT_DIR/flake.nix" ]; then
            cp "$SCRIPT_DIR/flake.nix" /mnt/etc/nixos/
            cp "$SCRIPT_DIR/configuration.nix" /mnt/etc/nixos/
            cp "$SCRIPT_DIR/home.nix" /mnt/etc/nixos/
            
            # Обновляем LUKS устройство в конфигурации
            sed -i "s|device = \".*\";|device = \"$LUKS\";|" /mnt/etc/nixos/configuration.nix
            
            success "Оптимизированная конфигурация скопирована"
        else
            warning "Файлы конфигурации не найдены в текущей директории"
            warning "Будет использована стандартная конфигурация"
            nano /mnt/etc/nixos/configuration.nix
        fi
        ;;
    2)
        info "Редактирование стандартной конфигурации..."
        warning "Не забудьте раскомментировать нужные опции:"
        echo "• boot.loader.systemd-boot.enable = true;"
        echo "• networking.networkmanager.enable = true;"
        echo "• users.users.yourusername = {...};"
        echo "• services.xserver.enable = true; (если нужен)"
        pause
        nano /mnt/etc/nixos/configuration.nix
        ;;
esac

success "Конфигурация подготовлена"
pause

# Этап 8: Установка
info "Этап 8/8: Установка NixOS"

if [ -f "/mnt/etc/nixos/flake.nix" ]; then
    info "Установка с flake конфигурацией..."
    cd /mnt/etc/nixos
    nixos-install --flake .#PC-NixOS --no-root-passwd
else
    info "Установка со стандартной конфигурацией..."
    nixos-install --no-root-passwd
fi

success "🎉 NixOS установлена успешно!"

echo
echo "════════════════════════════════════════════════════════════════"
echo "✅ Установка завершена!"
echo
echo "📋 Следующие шаги:"
echo "1. Установите пароль пользователя после первой загрузки"  
echo "2. При загрузке введите пароль LUKS для расшифровки диска"
echo "3. Система автоматически войдет в систему"
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
cryptsetup luksClose nixos-root

warning "Извлеките установочный носитель и перезагрузитесь"
read -p "Перезагрузить сейчас? (y/N): " REBOOT
if [[ $REBOOT =~ ^[Yy]$ ]]; then
    reboot
fi